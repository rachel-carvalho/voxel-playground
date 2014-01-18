window.log = log = -> console.log.apply console, arguments

THREE = window.THREE
Mesher = require './mesher.coffee'

class Game
  constructor: ->
    {@THREE, THREE} = window

    @map = new Map this, onLoad: =>
      @container = document.getElementById("container")

      @clock = new THREE.Clock()

      @camera = @createCamera()
  
      @scene = @createScene()
  
      @avatar = @createAvatar()
      
      @renderer = @createRenderer()    
      
      @stats = @createStats()

      window.addEventListener "resize", @onWindowResize, false

      @animate()

  createAvatar: ->
    {THREE} = this
    {voxelSize} = @map.config

    width = voxelSize / 2
    height = voxelSize * 1.7

    g = new THREE.CubeGeometry width, height, width

    mat = new THREE.MeshLambertMaterial color: 0x0000cc

    avatar = new THREE.Mesh g, mat
    y = height / 2
    avatar.position.y = y

    @controls = @createControls(avatar)

    @controls.yawObject.add avatar

    avatar

  getAvatarY: (x, z) ->
    {voxelSize} = @map.config

    y = ((@map.getY(x, z) + 0.5) * voxelSize)

    y

  createCamera: ->
    {THREE} = this
    
    new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 1, 20000)

  createControls: (avatar) ->
    {THREE} = this
    {voxelSize} = @map.config

    element = document.body
    pointerlockchange = (event) =>
      # todo: toggle instructions
      @controls.enabled = document.pointerLockElement is element or document.mozPointerLockElement is element or document.webkitPointerLockElement is element

    for vendor in ['', 'moz', 'webkit']
      document.addEventListener "#{vendor}pointerlockchange", pointerlockchange, false
      element.requestPointerLock = element.requestPointerLock or element["#{vendor}RequestPointerLock"]

    # todo: request fullscreen first for firefox
    element.addEventListener 'click', (e) ->
      element.requestPointerLock()
    , false

    controls = new THREE.PointerLockControls
      camera: @camera
      avatar: avatar
      voxelSize: voxelSize
      threelyToVoxelyCoords: (c) => @map.threelyToVoxelyCoords(c)
      getAvatarY: (x, z) => @getAvatarY(x, z)

    controls.getObject().position.y = @getAvatarY 0, 0

    @scene.add controls.getObject()

    controls.pitchObject.position.y = voxelSize * 1.5

    controls

  createScene: ->
    {THREE} = this
    
    scene = new THREE.Scene()

    scene.fog = new THREE.FogExp2(0xf2c8b8, 0.00015)
    scene.add new THREE.AmbientLight(0xcccccc)

    directionalLight = new THREE.DirectionalLight(0xffffff, 2)
    directionalLight.position.set(1, 1, -0.5).normalize()
    scene.add directionalLight
    
    scene

  createRenderer: ->
    {THREE} = this

    renderer = new THREE.WebGLRenderer(antialias: true)
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

  animate: ->
    window.requestAnimationFrame game.animate
    game.render()

  render: ->
    @stats.update()
    @map.updateChunks(@controls.getObject().position)
    @controls.update @clock.getDelta() * 1000
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

  threelyToVoxelyCoords: (threelyCoords) ->
    {voxelSize} = @config

    {x, z} = threelyCoords
    
    x: Math.floor x / voxelSize
    z: Math.floor z / voxelSize

  getChunkyCoords: (threelyCoords) ->
    {chunkSize} = @config

    voxelCoords = @threelyToVoxelyCoords threelyCoords
    
    x: Math.floor voxelCoords.x / chunkSize
    z: Math.floor voxelCoords.z / chunkSize
  
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