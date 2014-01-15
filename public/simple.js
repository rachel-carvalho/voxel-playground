var voxelEngine = require('voxel-engine');

var voxelPlayer = require('voxel-player');

var game = window.game = voxelEngine({
  materials: ['mars'],
  generate: function(x, y, z) {
    // return y == 0 ? 1 : 0;
    var xMod20 = Math.abs(x % 20);
    if (
        (y == 0)
        || (y == 1 && (xMod20 > 0 && xMod20 < 10))
        || (y == 2 && (xMod20 > 4 && xMod20 < 6))
      )
      return 1;
    else
      return 0;
  }
});

game.appendTo(document.body);

var player = window.player = voxelPlayer(game)();

player.position.set(100000, 20, 100000);

player.possess();

game.paused = false;