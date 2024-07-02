const rl = @import("raylib");
const std = @import("std");

const board = @import("board.zig");
const tetromino = @import("tetromino.zig");

const screenWidth = 1200;
const screenHeight = 900;

pub fn main() anyerror!void {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var g_board = board.Board{ .allocator = allocator };
    g_board.init(&prng, tetromino.Vec2{.x = screenWidth * 0.7, .y = screenHeight * 0.9}) catch |err| {
        return err;
    };

    defer g_board.deinit();

    rl.initWindow(screenWidth, screenHeight, "Tetris");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var sumTime: f32 = 0;
    var speed: f16 = 0.8;

    while (!rl.windowShouldClose()) {
        const deltaTime: f32 = rl.getFrameTime();
        sumTime += deltaTime;

        if (sumTime > 1 / speed) {
            g_board.moveTetromino(&prng, tetromino.Direction.Down);
            sumTime = 0;
            speed += 0;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_left)) {
            g_board.moveTetromino(&prng, tetromino.Direction.Left);
        } else if (rl.isKeyPressed(rl.KeyboardKey.key_right)) {
            g_board.moveTetromino(&prng, tetromino.Direction.Right);
        } else if (rl.isKeyPressed(rl.KeyboardKey.key_down)) {
            g_board.moveTetromino(&prng, tetromino.Direction.Down);
        } else if (rl.isKeyPressed(rl.KeyboardKey.key_up)) {
            g_board.rotateTetromino();
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        g_board.draw();
    }
}
