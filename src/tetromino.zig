const rl = @import("raylib");
const std = @import("std");

pub const tile_size = 50;

pub const Direction = enum{
    Left,
    Right,
	Down,
};

pub fn Vec2(comptime T: type) type {
	return struct {
		x: T = 0,
		y: T = 0,
	};
}

pub const Tetromino = struct{
    data: [16]u1,
    position: ?Vec2(i16) = null,
    color: rl.Color,

    pub fn print(self: Tetromino) void {
        for (0.., self.data) |index, element| {
            if (index % 4 == 0) {
                std.debug.print("\n", .{});
            }
            std.debug.print("{d} ", .{element});
        }
        std.debug.print("\n", .{});
    }

    pub fn getNonBlankLine(self: Tetromino, direction: Direction) !usize {
		const line = switch (direction) {
			Direction.Left => blk: {
				for (0..4) |index_x| {
					for(0..4) |index_y| {
						if (self.data[index_y * 4 + index_x] == 1) break :blk index_x;
					}
				}
				break :blk error.Error;
			},
			Direction.Right => blk: {
				for (0..4) |index| {
					const index_x = 3 - index;
					for(0..4) |index_y| {
						if (self.data[index_y * 4 + index_x] == 1) break :blk index_x;
					}
				}
				break :blk error.Error;
			},
			Direction.Down => blk: {
				for (0..4) |index| {
					const index_y = 3 - index;
					for(0..4) |index_x| {
						if (self.data[index_y * 4 + index_x] == 1) break :blk index_y;
					}
				}
				break :blk error.Error;
			}
		};
		return line;
	}

    pub fn draw(self: Tetromino) void {
        if (self.position) |pos| {
            for (0.., self.data) |index, element| {
                if (element == 0) {
					continue;
				}
				const x_offset: i16 = @intCast(index % 4);
				const y_offset: i16 = @intCast(index / 4);
				const rect = rl.Rectangle{
					.x = @floatFromInt((pos.x + x_offset) * tile_size),
					.y = @floatFromInt((pos.y + y_offset) * tile_size),
					.width = tile_size,
					.height = tile_size,
				};

				rl.drawRectangleRec(rect, self.color);
				rl.drawRectangleLinesEx(rect, 2, rl.Color.black);
            }
        } else return;
    }

    pub fn drawMiniature(self: Tetromino, position: Vec2(i16)) void {
		for (0.., self.data) |index, element| {
			if (element == 0) {
				continue;
			}
			const x_offset: i16 = @intCast(index % 4 * (tile_size / 2));
			const y_offset: i16 = @intCast(index / 4 * (tile_size / 2));
			const rect = rl.Rectangle{
				.x = @floatFromInt(position.x + x_offset),
				.y = @floatFromInt(position.y + y_offset),
				.width = tile_size / 2,
				.height = tile_size / 2,
			};

			rl.drawRectangleRec(rect, self.color);
			rl.drawRectangleLinesEx(rect, 1, rl.Color.black);
		}
	}
};

const l_shape = Tetromino{
	.data = .{
		0, 0, 0, 0,
		0, 1, 0, 0,
		0, 1, 0, 0,
		0, 1, 1, 0,
	},
	.color = rl.Color.orange,
};
const j_shape = Tetromino{
	.data = .{
		0, 0, 0, 0,
		0, 0, 1, 0,
		0, 0, 1, 0,
		0, 1, 1, 0,
	},
	.color = rl.Color.purple,
};
const o_shape = Tetromino{
	.data = .{
		0, 0, 0, 0,
		0, 1, 1, 0,
		0, 1, 1, 0,
		0, 0, 0, 0,
	},
	.color = rl.Color.yellow,
};
const z_shape = Tetromino{
	.data = .{
		0, 0, 0, 0,
		1, 1, 0, 0,
		0, 1, 1, 0,
		0, 0, 0, 0,
	},
	.color = rl.Color.green,
};
const s_shape = Tetromino{
	.data = .{
		0, 0, 0, 0,
		0, 1, 1, 0,
		1, 1, 0, 0,
		0, 0, 0, 0,
	},
	.color = rl.Color.blue
};
const i_shape = Tetromino{
	.data = .{
		0, 0, 0, 0,
		1, 1, 1, 1,
		0, 0, 0, 0,
		0, 0, 0, 0,
	},
	.color = rl.Color.red,
};
const w_shape = Tetromino{
	.data = .{
		0, 0, 0, 0,
		0, 1, 0, 0,
		1, 1, 1, 0,
		0, 0, 0, 0,
	},
	.color = rl.Color.pink,
};

pub const possible_shapes = [_]Tetromino{l_shape, o_shape, z_shape, s_shape, i_shape, w_shape, j_shape};
