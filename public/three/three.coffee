log = -> console.log.apply console, arguments

THREE = window.THREE
Mesher = require './mesher.coffee'

class Game
  constructor: ->
    {@THREE, THREE} = window

    @map = new Map this, onLoad: =>
      @container = document.getElementById("container")

      @clock = new THREE.Clock()

      @camera = @createCamera()
  
      @controls = @createControls()    
      
      @scene = @createScene()
  
      @renderer = @createRenderer()    
      
      @stats = @createStats()

      window.addEventListener "resize", @onWindowResize, false
      
      @animate()  

  createCamera: ->
    {THREE} = this
    {voxelSize} = @map.config
    
    camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 1, 20000)
    camera.position.y = (@map.getY(0, 0) * voxelSize) + voxelSize
    
    camera

  createControls: ->
    {THREE} = this

    controls = new THREE.FirstPersonControls(@camera)
    controls.movementSpeed = 1000
    controls.lookSpeed = 0.125
    controls.lookVertical = true
    controls.constrainVertical = true
    controls.verticalMin = 1.1
    controls.verticalMax = 2.2
    
    controls

  createScene: ->
    {THREE} = this
    
    scene = new THREE.Scene()

    scene.fog = new THREE.FogExp2(0xf2c8b8, 0.00015)
    scene.add new THREE.AmbientLight(0xcccccc)

    directionalLight = new THREE.DirectionalLight(0xffffff, 2)
    directionalLight.position.set(1, 1, 0.5).normalize()
    scene.add directionalLight
    
    scene

  createRenderer: ->
    {THREE} = this

    renderer = new THREE.WebGLRenderer(alpha: false)
    renderer.setClearColor 0xf2c8b8
    renderer.setSize window.innerWidth, window.innerHeight
    
    @container.appendChild renderer.domElement
    
    renderer

  createStats: ->
    stats = new Stats()
    stats.domElement.style.position = 'absolute'
    stats.domElement.style.bottom = '0px'
    @container.appendChild stats.domElement
    
    stats
  
  onWindowResize: ->
    {innerWidth, innerHeight} = window
    
    @camera.aspect = innerWidth / innerHeight
    @camera.updateProjectionMatrix()

    @renderer.setSize innerWidth, innerHeight

    @controls.handleResize()
  
  animate: ->
    window.requestAnimationFrame game.animate
    game.render()

  render: ->
    @stats.update()
    @map.updateChunks(@camera.position)
    @controls.update @clock.getDelta()
    @renderer.render @scene, @camera

class Map
  constructor: (@game, params) ->
    {THREE} = @game

    voxelSize = 100
    chunkSize = 32
    chunkDistance = 2

    @config = {chunkSize, voxelSize, chunkDistance}

    @chunks = {}

    @mesher = new Mesher {THREE, voxelSize, chunkSize}
    
    @loadImage './maps/mars-zone.png', (img) =>
      canvas = document.createElement 'canvas'
      canvas.width = img.width
      canvas.height = img.height
      ctx = canvas.getContext '2d'
      ctx.drawImage img, 0, 0
      
      @zone = ctx.getImageData(0, 0, img.width, img.height).data
      @zoneWidth = img.width

      params.onLoad()

  loadImage: (path, callback) ->
    img = new Image()
    img.onload = -> callback(img)
    img.src = path
    
    img

  getChunkyCoords: (threelyCoords) ->
    {x, z} = threelyCoords
    {voxelSize, chunkSize} = @config
    
    x: Math.floor x / voxelSize / chunkSize
    z: Math.floor z / voxelSize / chunkSize
  
  getY: (x, z) ->
    i = (@zoneWidth * z + x) << 2
    height = @zone[i]
  
    Math.ceil (height / 255) * 255

  updateChunks: (currentThreelyPosition) ->
    if not @updatingChunks
      @updatingChunks = yes
    
      newp = @getChunkyCoords(currentThreelyPosition)
      oldp = @currentChunkyPosition
      
      if not oldp or oldp.x isnt newp.x or oldp.z isnt newp.z
        @currentChunkyPosition = newp
        oldp ?= newp
        
        cd = @config.chunkDistance
        
        startX = Math.min oldp.x - cd, newp.x - cd
        endX = Math.max oldp.x + cd, newp.x + cd
  
        startZ = Math.min oldp.z - cd, newp.z - cd
        endZ = Math.max oldp.z + cd, newp.z + cd
  
        for x in [startX..endX]
          for z in [startZ..endZ]
            if x < newp.x - cd or x > newp.x + cd or z < newp.z - cd or z > newp.z + cd
              if @chunks["#{x},#{z}"]
                @deleteChunk(x, z)
            else
              if not @chunks["#{x},#{z}"]
                @generateChunk(x, z)
                
      @updatingChunks = no

  generateChunk: (chunkX, chunkZ) ->
    {game} = this
    {chunkSize} = @config
    
    startZ = chunkZ * chunkSize
    startX = chunkX * chunkSize
    
    endZ = startZ + chunkSize
    endX = startX + chunkSize
  
    @chunks["#{chunkX},#{chunkZ}"] = mesh = @mesher.generate 
      zArray: [startZ...endZ]
      xArray: [startX...endX]
      getY: (x, z) => @getY(x, z)

    game.scene.add mesh

  deleteChunk: (chunkX, chunkZ) ->
    mesh = @chunks["#{chunkX},#{chunkZ}"]
    if mesh
      @game.scene.remove(mesh)
      delete @chunks["#{chunkX},#{chunkZ}"]
      mesh.geometry.dispose()
      delete mesh.data
      delete mesh.geometry
      delete mesh.meshed

window.game = new Game()