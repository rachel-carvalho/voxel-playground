class Mesher
  constructor: (opts) ->
    {@THREE, THREE, voxelSize, chunkSize} = opts

    @light = new THREE.Color(0x999999)
    @shadow = new THREE.Color(0x505050)

    @matrix = new THREE.Matrix4()

    @config = {voxelSize, chunkSize}

    @material = @createMaterial()

    @createGeometry()


  createMaterial: ->
    {THREE} = this
    
    texture = THREE.ImageUtils.loadTexture("textures/atlas.png")
    texture.magFilter = THREE.NearestFilter
    texture.minFilter = THREE.LinearMipMapLinearFilter

    new THREE.MeshLambertMaterial
      map: texture, ambient: 0xbbbbbb, vertexColors: THREE.VertexColors


  createGeometry: ->
    {shadow, light} = this

    @pxGeometry = @generateVoxelGeometry
      faces: [[light, shadow, light], [shadow, shadow, light]]
      rotationY: Math.PI / 2, translation: [50, 0, 0]
      uvs: (fvu) -> [fvu[0][0][0], fvu[0][0][2], fvu[0][1][2]]

    @nxGeometry = @generateVoxelGeometry
      faces: [[light, shadow, light], [shadow, shadow, light]]
      rotationY: -Math.PI / 2, translation: [-50, 0, 0]
      uvs: (fvu) -> [fvu[0][0][0], fvu[0][0][2], fvu[0][1][2]]

    @pyGeometry = @generateVoxelGeometry
      faces: [[light, light, light], [light, light, light]]
      rotationX: -Math.PI / 2, translation: [0, 50, 0]
      uvs: (fvu) -> [fvu[0][0][1], fvu[0][1][0], fvu[0][1][1]]

    @py2Geometry = @generateVoxelGeometry
      faces: [[light, light, light], [light, light, light]]
      rotationX: -Math.PI / 2, rotationY: Math.PI / 2, translation: [0, 50, 0]
      uvs: (fvu) -> [fvu[0][0][1], fvu[0][1][0], fvu[0][1][1]]

    @pzGeometry = @generateVoxelGeometry
      faces: [[light, shadow, light], [shadow, shadow, light]]
      translation: [0, 0, 50]
      uvs: (fvu) -> [fvu[0][0][0], fvu[0][0][2], fvu[0][1][2]]

    @nzGeometry = @generateVoxelGeometry
      faces: [[light, shadow, light], [shadow, shadow, light]]
      rotationY: Math.PI, translation: [0, 0, -50]
      uvs: (fvu) -> [fvu[0][0][0], fvu[0][0][2], fvu[0][1][2]]
    

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


  generate: (opts) ->
    {zArray, xArray, getY} = opts
    {voxelSize, chunkSize} = @config
    {pxGeometry, nxGeometry, pyGeometry, py2Geometry, pzGeometry, nzGeometry} = this

    geometry = new THREE.Geometry()
    dummy = new THREE.Mesh()

    for z in zArray
      for x in xArray
        h = getY(x, z)
  
        dummy.position.x = (x * voxelSize)
        dummy.position.y = h * voxelSize
        dummy.position.z = (z * voxelSize)
        
        px = getY(x + 1, z)
        nx = getY(x - 1, z)
        pz = getY(x, z + 1)
        nz = getY(x, z - 1)
  
        pxpz = getY(x + 1, z + 1)
        nxpz = getY(x - 1, z + 1)
        pxnz = getY(x + 1, z - 1)
        nxnz = getY(x - 1, z - 1)
  
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
  
    new THREE.Mesh geometry, @material


module.exports = Mesher