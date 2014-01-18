/**
 * @author mrdoob / http://mrdoob.com/
 */

THREE.PointerLockControls = function ( opts ) {

  var scope = this;

  var camera = opts.camera;
  var avatar = opts.avatar;
  var getAvatarY = opts.getAvatarY;
  var voxelSize = opts.voxelSize;
  var threelyToVoxelyCoords = opts.threelyToVoxelyCoords;

  camera.rotation.set( 0, 0, 0 );

  var pitchObject = this.pitchObject = new THREE.Object3D();
  pitchObject.add( camera );

  var yawObject = this.yawObject = new THREE.Object3D();
  yawObject.add( pitchObject );

  var moveForward = false;
  var moveBackward = false;
  var moveLeft = false;
  var moveRight = false;

  var canJump = false;

  var velocity = new THREE.Vector3();

  var walkSpeed = 0.8;
  var jumpHeight = 15;
  var maxWalkSpeed = walkSpeed * 5;
  var walkDeceleration = 0.08;
  var maxDeceleration = walkDeceleration * 5;

  var PI_2 = Math.PI / 2;

  var onMouseMove = function ( event ) {

    if ( scope.enabled === false ) return;

    var movementX = event.movementX || event.mozMovementX || event.webkitMovementX || 0;
    var movementY = event.movementY || event.mozMovementY || event.webkitMovementY || 0;

    yawObject.rotation.y -= movementX * 0.002;
    pitchObject.rotation.x -= movementY * 0.002;

    pitchObject.rotation.x = Math.max( - PI_2, Math.min( PI_2, pitchObject.rotation.x ) );

  };

  var onKeyDown = function ( event ) {

    switch ( event.keyCode ) {

      case 38: // up
      case 87: // w
        moveForward = true;
        break;

      case 37: // left
      case 65: // a
        moveLeft = true; break;

      case 40: // down
      case 83: // s
        moveBackward = true;
        break;

      case 39: // right
      case 68: // d
        moveRight = true;
        break;

      case 32: // space
        if ( canJump === true ) velocity.y += jumpHeight;
        canJump = false;
        break;

    }

  };

  var onKeyUp = function ( event ) {

    switch( event.keyCode ) {

      case 38: // up
      case 87: // w
        moveForward = false;
        break;

      case 37: // left
      case 65: // a
        moveLeft = false;
        break;

      case 40: // down
      case 83: // s
        moveBackward = false;
        break;

      case 39: // right
      case 68: // d
        moveRight = false;
        break;

    }

  };

  document.addEventListener( 'mousemove', onMouseMove, false );
  document.addEventListener( 'keydown', onKeyDown, false );
  document.addEventListener( 'keyup', onKeyUp, false );

  this.enabled = false;

  this.getObject = function () {

    return yawObject;

  };


  this.getDirection = function() {

    // assumes the camera itself is not rotated

    var direction = new THREE.Vector3( 0, 0, -1 );
    var rotation = new THREE.Euler( 0, 0, 0, "YXZ" );

    return function( v ) {

      rotation.set( pitchObject.rotation.x, yawObject.rotation.y, 0 );

      v.copy( direction ).applyEuler( rotation );

      return v;

    }

  }();

  var getRotatedVelocity = function() {
    var v = velocity.clone();
    v.applyQuaternion(yawObject.quaternion);
    return v;
  };

  var setRotatedVelocity = function(rotatedVelocity) {
    var v = rotatedVelocity.clone();
    v.applyQuaternion(yawObject.quaternion.clone().inverse());
    velocity.set(v.x, v.y, v.z);
  };

  var getBounds2D = function(mesh, velocity) {
    var w = mesh.geometry.width;
    var d = mesh.geometry.depth;

    var bounds = [];
    for (var x = 0; x < 2; x++){
      for (var z = 0; z < 2; z++){
        var point = yawObject.position.clone().add(mesh.position).add(new THREE.Vector3(w * (x + 0.5), 0, d * (z + 0.5)));
        
        if (velocity) point.add(velocity);
        
        bounds.push({
          threely: point,
          voxely: threelyToVoxelyCoords(point)
        });
      }
    }

    return bounds;
  };

  var getHighestFloor = function(bounds) {
    var floor = 0;
    for (var i = 0; i < bounds.length; i++)
      floor = Math.max(floor, getAvatarY(bounds[i].voxely.x, bounds[i].voxely.z));
    return floor;
  };

  var avoided = false;
  var avoidCollisions = function(rotatedVelocity, floor, voxelsP) {
    var p = yawObject.position.clone();
    p.add(rotatedVelocity);

    // new voxel and floor
    var newVoxelsP = getBounds2D(avatar, rotatedVelocity);
    var newFloor = getHighestFloor(newVoxelsP);

    // new y is higher than previous floor and player hasn't jumped enough
    if (newFloor > floor && p.y < newFloor) {
      var velocityReset = false;
      
      var axes = ['x', 'z'];

      for (var j = 0; j < axes.length; j++) {
        var axis = axes[j];
        // changed voxels on both axes
        for (var i = 0; i < voxelsP.length; i++){
          var voxelP = voxelsP[i].voxely;
          var newVoxelP = newVoxelsP[i].voxely;
          if (voxelP[axis] != newVoxelP[axis]){
            rotatedVelocity[axis] = 0;
            velocityReset = true;
          }
        }
      }

      // if velocity is reset, we re-run predictions before testing vertical velocity
      if (velocityReset) {
        // if avoidCollisions has been called once from inside
        // and is being called again, something is very wrong
        if (avoided) {
          log('damn it, carl');
          return;
        }

        avoided = true;
        avoidCollisions(rotatedVelocity, floor, voxelsP);
        return;
      }
    }

    if (p.y < newFloor) {
      rotatedVelocity.y = 0;
      yawObject.position.y = newFloor;
      canJump = true;
    }
  };

  this.update = function ( delta ) {
    if ( scope.enabled === false ) return;

    delta *= 0.1;

    var deceleration = Math.min(walkDeceleration * delta, maxDeceleration);

    velocity.x += ( - velocity.x ) * deceleration;
    velocity.z += ( - velocity.z ) * deceleration;

    velocity.y -= 0.25 * delta;

    var speed = Math.min(walkSpeed * delta, maxWalkSpeed);

    if ( moveForward ) velocity.z -= speed;
    if ( moveBackward ) velocity.z += speed;

    if ( moveLeft ) velocity.x -= speed;
    if ( moveRight ) velocity.x += speed;

    var rotatedVelocity = getRotatedVelocity();

    var voxelsP = getBounds2D(avatar);
    var floor = getHighestFloor(voxelsP);

    avoided = false;
    avoidCollisions(rotatedVelocity, floor, voxelsP);

    setRotatedVelocity(rotatedVelocity);
    yawObject.position.add(rotatedVelocity);
  };

};
