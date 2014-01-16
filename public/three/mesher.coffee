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

    @pxVertexColors = (@pxGeometry.faces[i].vertexColors for i in [0..1])

    @nxGeometry = @generateVoxelGeometry
      faces: [[light, shadow, light], [shadow, shadow, light]]
      rotationY: -Math.PI / 2, translation: [-50, 0, 0]
      uvs: (fvu) -> [fvu[0][0][0], fvu[0][0][2], fvu[0][1][2]]

    @nxVertexColors = (@nxGeometry.faces[i].vertexColors for i in [0..1])

    @pyGeometry = @generateVoxelGeometry
      faces: [[light, light, light], [light, light, light]]
      rotationX: -Math.PI / 2, translation: [0, 50, 0]
      uvs: (fvu) -> [fvu[0][0][1], fvu[0][1][0], fvu[0][1][1]]

    @pyVertexColors = (@pyGeometry.faces[i].vertexColors for i in [0..1])

    @pzGeometry = @generateVoxelGeometry
      faces: [[light, shadow, light], [shadow, shadow, light]]
      translation: [0, 0, 50]
      uvs: (fvu) -> [fvu[0][0][0], fvu[0][0][2], fvu[0][1][2]]

    @pzVertexColors = (@pzGeometry.faces[i].vertexColors for i in [0..1])

    @nzGeometry = @generateVoxelGeometry
      faces: [[light, shadow, light], [shadow, shadow, light]]
      rotationY: Math.PI, translation: [0, 0, -50]
      uvs: (fvu) -> [fvu[0][0][0], fvu[0][0][2], fvu[0][1][2]]
    
    @nzVertexColors = (@nzGeometry.faces[i].vertexColors for i in [0..1])


  generateVoxelGeometry: (opts) ->
    {THREE, matrix} = this
    {voxelSize} = @config
    
    g = new THREE.PlaneGeometry(voxelSize, voxelSize)
  
    for i in [0..1]
      g.faces[i].vertexColors.push.apply g.faces[i].vertexColors, opts.faces[i]
  
    uv.y = 0.5 for uv in opts.uvs(g.faceVertexUvs)
  
    g.applyMatrix matrix.makeRotationX(opts.rotationX) if opts.rotationX
    g.applyMatrix matrix.makeRotationY(opts.rotationY) if opts.rotationY
    
    g.applyMatrix matrix.makeTranslation.apply(matrix, opts.translation)
  
    g


  mergeVoxelGeometry: (voxelGeometry, defaultFaceColors, chunkGeometry, dummy, vertices) ->
    {shadow, light} = this
    
    dummy.geometry = voxelGeometry

    for i in [0, 1]
      dummy.geometry.faces[i].vertexColors = defaultFaceColors[i].slice()

    for v in vertices
      face = v[0]
      vertexIndex = v[1]
      shadowed = v[2]
      dummy.geometry.faces[face].vertexColors[vertexIndex] = (if shadowed then shadow else light)

    THREE.GeometryUtils.merge chunkGeometry, dummy


  generate: (opts) ->
    {zArray, xArray, getY} = opts

    geometry = new THREE.Geometry()
    dummy = new THREE.Mesh()

    for z in zArray
      for x in xArray
        @generateColumn
          top: yes

          dummy: dummy
          geometry: geometry

          h: getY(x, z)
          x: x
          z: z
          
          px: getY(x + 1, z)
          nx: getY(x - 1, z)
          pz: getY(x, z + 1)
          nz: getY(x, z - 1)

          pxpz: getY(x + 1, z + 1)
          nxpz: getY(x - 1, z + 1)
          pxnz: getY(x + 1, z - 1)
          nxnz: getY(x - 1, z - 1)
  
    new THREE.Mesh geometry, @material


  generateColumn: (opts)->
    {x, z, h} = opts
    {px, nx, pz, nz} = opts
    {pxpz, nxpz, pxnz, nxnz} = opts
    {dummy, geometry} = opts

    {voxelSize, chunkSize} = @config
    {pxGeometry, nxGeometry, pyGeometry, pzGeometry, nzGeometry} = this
    {pxVertexColors, nxVertexColors, pyVertexColors, pzVertexColors, nzVertexColors} = this

    # PXPZ PZ NXPZ
    #   PX 00 NX
    # PXNZ NZ NXNZ

    # if right, down, or right-bottom diagonal is higher, a is 0 else it's 1
    a = (if nx > h or nz > h or nxnz > h then 0 else 1)
    # if right, up, or right-top diagonal is higher, b is 0 else it's 1
    b = (if nx > h or pz > h or nxpz > h then 0 else 1)
    # if left, up, or left-top diagonal is higher, c is 0 else it's 1
    c = (if px > h or pz > h or pxpz > h then 0 else 1)
    # if left, down, or left-bottom diagonal is higher, d is 0 else it's 1
    d = (if px > h or nz > h or pxnz > h then 0 else 1)

    dummy.position.x = (x * voxelSize)
    dummy.position.y = h * voxelSize
    dummy.position.z = (z * voxelSize)
    
    if opts.top
      @mergeVoxelGeometry pyGeometry, pyVertexColors, geometry, dummy, [
        [0, 0, a is 0], [0, 1, b is 0], [0, 2, d is 0]
        [1, 0, b is 0], [1, 1, c is 0], [1, 2, d is 0]
      ]

    first = 0
    last = chunkSize - 1

    diffPX = h - px
    diffNX = h - nx
    diffPZ = h - pz
    diffNZ = h - nz

    if diffPX > 0 or x is first
      pzIsSameOrHigher = pz >= h
      pxpzIsSameOrHigher = pxpz >= h

      shadows = 
        topRight: pxnz > px and px is h - 1 and x > first
        topLeft: pzIsSameOrHigher and pxpzIsSameOrHigher
      vertices = []

      
      if diffPX > 1
        pxnzIs1Lower = pxnz is h - 1

        pxnzIsSameOrHigher = pxnz >= h
        pxpzIs1Lower = pxpz is h - 1

        shadows.bottomRight = pxnzIs1Lower or pxnzIsSameOrHigher
        shadows.topRight = shadows.topRight or pxnzIsSameOrHigher
        shadows.bottomLeft = pxpzIs1Lower or shadows.topLeft

        vertices.push [0, 1, shadows.bottomLeft], 
                      [1, 0, shadows.bottomLeft],
                      [1, 1, shadows.bottomRight]


      vertices.push [0, 2, shadows.topRight],
                    [1, 2, shadows.topRight],
                    [0, 0, shadows.topLeft]

      @mergeVoxelGeometry pxGeometry, pxVertexColors, geometry, dummy, vertices

    if diffNX > 0 or x is last
      @mergeVoxelGeometry nxGeometry, nxVertexColors, geometry, dummy,
        [
          [0, 0, nxnz > nx and x < last], 
          [0, 2, nxpz > nx and x < last], 
          [1, 2, nxpz > nx and x < last]
        ]
    
    if diffPZ > 0 or z is last
      @mergeVoxelGeometry pzGeometry, pzVertexColors, geometry, dummy,
        [
          [0, 0, nxpz > pz and z < last], 
          [0, 2, pxpz > pz and z < last], 
          [1, 2, pxpz > pz and z < last]
        ]
    
    if diffNZ > 0 or z is first
      @mergeVoxelGeometry nzGeometry, nzVertexColors, geometry, dummy,
        [
          [0, 0, pxnz > nz and z > first], 
          [0, 2, nxnz > nz and z > first], 
          [1, 2, nxnz > nz and z > first]
        ]

    # while there's a larger than 1 height difference, keep drawing lower Ys
    if diffPX > 1 or diffNX > 1 or diffPZ > 1 or diffNZ > 1
      h--
      @generateColumn {h, x, z, px, nx, pz, nz, pxpz, nxpz, pxnz, nxnz, dummy, geometry}


module.exports = Mesher