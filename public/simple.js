var voxelEngine = require('voxel-engine');

var voxelPlayer = require('voxel-player');

var game = voxelEngine({
  materials: ['mars'],
  generate: function(x, y, z) {
    return y == 0 ? 1 : 0;
  }
});

game.appendTo(document.body);

var player = voxelPlayer(game)();

player.position.set(100000, 20, 100000);

player.possess();

game.paused = false;