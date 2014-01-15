log = -> console.log.apply console, arguments

THREE = window.THREE

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
    {@THREE, THREE} = @game

    @config =
      chunkSize: 32
      voxelSize: 100
      chunkDistance: 2

    @chunks = {}
    
    @light = new THREE.Color(0x999999)
    @shadow = new THREE.Color(0x505050)
    
    @matrix = new THREE.Matrix4()
    
    @texture = @createTexture()

    @loadImage './maps/mars-zone.png', (img) =>
      canvas = document.createElement 'canvas'
      canvas.width = img.width
      canvas.height = img.height
      ctx = canvas.getContext '2d'
      ctx.drawImage img, 0, 0
      
      @zone = ctx.getImageData(0, 0, img.width, img.height).data
      @zoneWidth = img.width

      params.onLoad()

  createTexture: ->
    {THREE} = this
    
    texture = THREE.ImageUtils.loadTexture("textures/atlas.png")
    texture.magFilter = THREE.NearestFilter
    texture.minFilter = THREE.LinearMipMapLinearFilter
    
    texture

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

  generateVoxelGeometry: (opts) ->
    {THREE, matrix} = this
    {voxelSize} = @config
    
    g = new THREE.PlaneGeometry(voxelSize, voxelSize)
  
    for i in [0, 1]
      g.faces[i].vertexColors.push.apply g.faces[i].vertexColors, opts.faces[i]
  
    uv.y = 0.5 for uv in opts.uvs(g.faceVertexUvs)
  
    g.applyMatrix matrix.makeRotationX(opts.rotationX) if opts.rotationX
    g.applyMatrix matrix.makeRotationY(opts.rotationY) if opts.rotationY
  
    g.applyMatrix matrix.makeTranslation.apply(matrix, opts.translation)
  
    g

  mergeVoxelGeometry: (voxelGeometry, chunkGeometry, dummy, faces) ->
    {shadow, light} = this
    
    dummy.geometry = voxelGeometry

    for f in faces
      dummy.geometry.faces[f[0]].vertexColors[f[1]] = (if f[2] then shadow else light)

    THREE.GeometryUtils.merge chunkGeometry, dummy

  generateChunk: (chunkX, chunkZ) ->
    {THREE, game, texture, shadow, light} = this
    {chunkSize, voxelSize} = game.map.config
    
    @chunks["#{chunkX},#{chunkZ}"] = {}
  
    pxGeometry = @generateVoxelGeometry
      faces: [[light, shadow, light], [shadow, shadow, light]]
      rotationY: Math.PI / 2, translation: [50, 0, 0]
      uvs: (fvu) -> [fvu[0][0][0], fvu[0][0][2], fvu[0][1][2]]

    nxGeometry = @generateVoxelGeometry
      faces: [[light, shadow, light], [shadow, shadow, light]]
      rotationY: -Math.PI / 2, translation: [-50, 0, 0]
      uvs: (fvu) -> [fvu[0][0][0], fvu[0][0][2], fvu[0][1][2]]

    pyGeometry = @generateVoxelGeometry
      faces: [[light, light, light], [light, light, light]]
      rotationX: -Math.PI / 2, translation: [0, 50, 0]
      uvs: (fvu) -> [fvu[0][0][1], fvu[0][1][0], fvu[0][1][1]]

    py2Geometry = @generateVoxelGeometry
      faces: [[light, light, light], [light, light, light]]
      rotationX: -Math.PI / 2, rotationY: Math.PI / 2, translation: [0, 50, 0]
      uvs: (fvu) -> [fvu[0][0][1], fvu[0][1][0], fvu[0][1][1]]

    pzGeometry = @generateVoxelGeometry
      faces: [[light, shadow, light], [shadow, shadow, light]]
      translation: [0, 0, 50]
      uvs: (fvu) -> [fvu[0][0][0], fvu[0][0][2], fvu[0][1][2]]

    nzGeometry = @generateVoxelGeometry
      faces: [[light, shadow, light], [shadow, shadow, light]]
      rotationY: Math.PI, translation: [0, 0, -50]
      uvs: (fvu) -> [fvu[0][0][0], fvu[0][0][2], fvu[0][1][2]]

    geometry = new THREE.Geometry()
    dummy = new THREE.Mesh()
    
    startZ = chunkZ * chunkSize
    startX = chunkX * chunkSize
    
    endZ = startZ + chunkSize
    endX = startX + chunkSize
  
    for z in [startZ...endZ]
      for x in [startX...endX]
        h = @getY(x, z)
  
        dummy.position.x = (x * voxelSize)
        dummy.position.y = h * voxelSize
        dummy.position.z = (z * voxelSize)
        
        px = @getY(x + 1, z)
        nx = @getY(x - 1, z)
        pz = @getY(x, z + 1)
        nz = @getY(x, z - 1)
  
        pxpz = @getY(x + 1, z + 1)
        nxpz = @getY(x - 1, z + 1)
        pxnz = @getY(x + 1, z - 1)
        nxnz = @getY(x - 1, z - 1)
  
        a = (if nx > h or nz > h or nxnz > h then 0 else 1)
        b = (if nx > h or pz > h or nxpz > h then 0 else 1)
        c = (if px > h or pz > h or pxpz > h then 0 else 1)
        d = (if px > h or nz > h or pxnz > h then 0 else 1)
  
        if a + c > b + d
          @mergeVoxelGeometry py2Geometry, geometry, dummy, [
            [0, 0, b is 0], [0, 1, c is 0], [0, 2, a is 0]
            [1, 0, c is 0], [1, 1, d is 0], [1, 2, a is 0]
          ]
        else
          @mergeVoxelGeometry pyGeometry, geometry, dummy, [
            [0, 0, a is 0], [0, 1, b is 0], [0, 2, d is 0]
            [1, 0, b is 0], [1, 1, c is 0], [1, 2, d is 0]
          ]
  
        if (px isnt h and px isnt h + 1) or x is 0
          @mergeVoxelGeometry pxGeometry, geometry, dummy,
            [[0, 0, pxpz > px and x > 0], [0, 2, pxnz > px and x > 0], [1, 2, pxnz > px and x > 0]]
  
        if (nx isnt h and nx isnt h + 1) or x is chunkSize - 1
          @mergeVoxelGeometry nxGeometry, geometry, dummy,
            [[0, 0, nxnz > nx and x < chunkSize - 1], [0, 2, nxpz > nx and x < chunkSize - 1], [1, 2, nxpz > nx and x < chunkSize - 1]]
        
        if (pz isnt h and pz isnt h + 1) or z is chunkSize - 1
          @mergeVoxelGeometry pzGeometry, geometry, dummy,
            [[0, 0, nxpz > pz and z < chunkSize - 1], [0, 2, pxpz > pz and z < chunkSize - 1], [1, 2, pxpz > pz and z < chunkSize - 1]]
        
        if (nz isnt h and nz isnt h + 1) or z is 0
          @mergeVoxelGeometry nzGeometry, geometry, dummy,
            [[0, 0, pxnz > nz and z > 0], [0, 2, nxnz > nz and z > 0], [1, 2, nxnz > nz and z > 0]]
  
    @chunks["#{chunkX},#{chunkZ}"] = mesh = new THREE.Mesh(geometry, new THREE.MeshLambertMaterial(
      map: texture, ambient: 0xbbbbbb, vertexColors: THREE.VertexColors
    ))
  
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