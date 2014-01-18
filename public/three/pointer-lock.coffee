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


  # @getDirection = =>
  #   # assumes the camera itself is not rotated
  #   direction = new THREE.Vector3(0, 0, -1)
  #   rotation = new THREE.Euler(0, 0, 0, "YXZ")
  #   (v) =>
  #     rotation.set @pitchObject.rotation.x, @yawObject.rotation.y, 0
  #     v.copy(direction).applyEuler rotation
  #     v
  # ()


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
        bounds.push
          threely: point
          voxely: @threelyToVoxelyCoords(point)

    bounds


  getHighestFloor: (bounds) ->
    floor = 0

    for b in bounds
      floor = Math.max floor, @getAvatarY(b.voxely.x, b.voxely.z)

    floor


  avoidCollisions: (rotatedVelocity, floor, voxelsP, avoided) ->
    p = @yawObject.position.clone()
    p.add rotatedVelocity
    
    # new voxel and floor
    newVoxelsP = @getBounds2D(@avatar, rotatedVelocity)
    newFloor = @getHighestFloor(newVoxelsP)
    
    # new y is higher than previous floor and player hasn't jumped enough
    if newFloor > floor and p.y < newFloor
      velocityReset = false

      for axis in ['x', 'z']        
        # changed voxels on both axes
        for i in [0...voxelsP.length]
          voxelP = voxelsP[i].voxely
          newVoxelP = newVoxelsP[i].voxely
          if voxelP[axis] isnt newVoxelP[axis]
            rotatedVelocity[axis] = 0
            velocityReset = true
      
      # if velocity is reset, we re-run predictions before testing vertical velocity
      if velocityReset

        # if avoidCollisions has been called once from inside
        # and is being called again, something is very wrong
        if avoided
          log 'damn it, carl'
          return

        @avoidCollisions rotatedVelocity, floor, voxelsP, true

        return

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