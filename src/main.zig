const rl = @import("raylib");
const std = @import("std");

const board = @import("board.zig");
const tetromino = @import("tetromino.zig");
const game = @import("game.zig");

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
    var g_board = board.Board{ .allocator = allocator, .game_speed = 0.8 };

    g_board.init(
        &prng,
        tetromino.Vec2(usize){.x = screenWidth * 0.5, .y = screenHeight }
    ) catch |err| {
        return err;
    };

    var game_handle = game.Game{
        .board = &g_board,
        .screen_size = tetromino.Vec2(usize){.x = screenWidth, .y = screenHeight},
    };

    defer game_handle.deinit();

    rl.initWindow(screenWidth, screenHeight, "Tetris");
    defer rl.closeWindow();

    rl.setTargetFPS(30);

    var sumTime: f32 = 0;

    while (!rl.windowShouldClose()) {
        game_handle.update(&prng, &sumTime);

        game_handle.handleInputs(&prng);

        rl.beginDrawing();
        defer rl.endDrawing();

        game_handle.draw();
    }
}
