###
@author mrdoob / http://mrdoob.com/
@author rachel-carvalho / https://github.com/rachel-carvalho
###

class PointerLockControls
  constructor: (opts) ->
    {@camera, @avatar, @getAvatarY, @threelyToVoxelyCoords} = opts

    @camera.rotation.set 0, 0, 0

    @pitchObject = new THREE.Object3D()
    @pitchObject.add @camera

    @yawObject = new THREE.Object3D()
    @yawObject.add @pitchObject

    @move =
      forward: false
      backward: false
      left: false
      right: false

    @canJump = false

    @velocity = new THREE.Vector3()

    @walkSpeed = 0.8
    @jumpHeight = 15
    @maxWalkSpeed = @walkSpeed * 5
    @walkDeceleration = 0.08
    @maxDeceleration = @walkDeceleration * 5

    @PI_2 = Math.PI / 2

    document.addEventListener 'mousemove', @onMouseMove, false
    document.addEventListener 'keydown', @onKeyDown, false
    document.addEventListener 'keyup', @onKeyUp, false

    @enabled = false
    

  onMouseMove: (event) =>
    return unless @enabled

    movementX = event.movementX or event.mozMovementX or event.webkitMovementX or 0
    movementY = event.movementY or event.mozMovementY or event.webkitMovementY or 0
    
    @yawObject.rotation.y -= movementX * 0.002
    @pitchObject.rotation.x -= movementY * 0.002
    
    @pitchObject.rotation.x = Math.max(-@PI_2, Math.min(@PI_2, @pitchObject.rotation.x))


  onKeyDown: (event) =>
    switch event.keyCode
      # up, w
      when 38, 87
        @move.forward = true
      
      # left, a
      when 37, 65
        @move.left = true
      
      # down, s
      when 40, 83
        @move.backward = true
      
      # right, d
      when 39, 68
        @move.right = true
      
      # space
      when 32
        @velocity.y += @jumpHeight if @canJump
        @canJump = false


  onKeyUp: (event) =>
    switch event.keyCode
      # up, w
      when 38, 87
        @move.forward = false

      # left, a
      when 37, 65
        @move.left = false
      
      # down, s
      when 40, 83
        @move.backward = false
      
      # right, d
      when 39, 68
        @move.right = false


  getObject: -> 
    @yawObject


  getRotatedVelocity: ->
    v = @velocity.clone()
    v.applyQuaternion @yawObject.quaternion
    v


  setRotatedVelocity: (rotatedVelocity) ->
    v = rotatedVelocity.clone()
    v.applyQuaternion @yawObject.quaternion.clone().inverse()
    @velocity.set v.x, v.y, v.z


  getBounds2D: (mesh, vel) ->
    w = mesh.geometry.width
    d = mesh.geometry.depth
    
    bounds = []

    for x in [0, 1]
      for z in [0, 1]
        point = @yawObject.position.clone().add(mesh.position).add(new THREE.Vector3(w * (x + 0.5), 0, d * (z + 0.5)))
        point.add vel if vel
        voxely = @threelyToVoxelyCoords(point)
        bounds.push
          threely: point
          voxely: voxely
          height: @getAvatarY(voxely.x, voxely.z)

    bounds


  getHighestFloor: (bounds) ->
    floor = 0

    for b in bounds
      floor = Math.max floor, b.height

    floor


  predictPositions: (v, floor) ->
    p = @yawObject.position.clone()
    p.add v
    newVoxelsP = @getBounds2D(@avatar, v)
    newFloor = @getHighestFloor(newVoxelsP)
    newFloorIsHigherAndPositionIsntEnough = newFloor > floor and p.y < newFloor

    {newVoxelsP, newFloor, newFloorIsHigherAndPositionIsntEnough, p}


  avoidCollisions: (rotatedVelocity, floor, voxelsP, avoided) ->
    originalVelocity = rotatedVelocity.clone()

    # new voxel and floor
    {newVoxelsP, newFloor, newFloorIsHigherAndPositionIsntEnough, p} = @predictPositions rotatedVelocity, floor
    
    resetVelocity =
      x: false
      z: false

    # for each axis,
    for axis in ['x', 'z']

      # new y is higher than previous floor and player hasn't jumped enough
      if newFloorIsHigherAndPositionIsntEnough

        # looks for voxel change
        for i in [0...voxelsP.length]
          voxelP = voxelsP[i]
          newVoxelP = newVoxelsP[i]
          originalVoxely = voxelP.voxely
          newVoxely = newVoxelP.voxely

          # if has changed voxel in any bounds and new voxel is higher 
          if originalVoxely[axis] isnt newVoxely[axis] and newVoxelP.height > voxelP.height
            other = if axis is 'x' then 'z' else 'x'

            # if other axis is already reset
            if resetVelocity[other]
              # undo and try resetting only this one
              resetVelocity[other] = false
              rotatedVelocity[other] = originalVelocity[other]

            # stop velocity and breaks bound loop for current axis
            rotatedVelocity[axis] = 0
            resetVelocity[axis] = true
            break
        
      # re-run predictions after each axis
      {newVoxelsP, newFloor, newFloorIsHigherAndPositionIsntEnough, p} = @predictPositions rotatedVelocity, floor

    # if only one axis still was not enough, reset both
    if newFloorIsHigherAndPositionIsntEnough
      rotatedVelocity.x = 0
      rotatedVelocity.z = 0
      {newVoxelsP, newFloor, newFloorIsHigherAndPositionIsntEnough, p} = @predictPositions rotatedVelocity, floor

    if p.y < newFloor
      rotatedVelocity.y = 0
      @yawObject.position.y = newFloor
      @canJump = true


  update: (delta) ->
    return unless @enabled

    delta *= 0.1
    
    deceleration = Math.min(@walkDeceleration * delta, @maxDeceleration)
    
    @velocity.x += (-@velocity.x) * deceleration
    @velocity.z += (-@velocity.z) * deceleration
    
    @velocity.y -= 0.25 * delta
    
    speed = Math.min(@walkSpeed * delta, @maxWalkSpeed)
    
    @velocity.z -= speed if @move.forward
    @velocity.z += speed if @move.backward
    @velocity.x -= speed if @move.left
    @velocity.x += speed if @move.right
    
    rotatedVelocity = @getRotatedVelocity()
    
    voxelsP = @getBounds2D(@avatar)
    
    @avoidCollisions rotatedVelocity, @getHighestFloor(voxelsP), voxelsP, false
    
    @setRotatedVelocity rotatedVelocity
    @yawObject.position.add rotatedVelocity

module.exports = PointerLockControls