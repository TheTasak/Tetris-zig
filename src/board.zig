const tetromino = @import("tetromino.zig");
const rl = @import("raylib");
const std = @import("std");

const Block = struct {
	color: ?rl.Color = null,

	fn draw(self: Block, position: tetromino.Vec2) void {
		const rect = rl.Rectangle{
				.x = position.x * tetromino.tile_size,
				.y = position.y * tetromino.tile_size,
				.width = tetromino.tile_size,
				.height = tetromino.tile_size,
		};

		// if color is not set then the block doesn't exist
		const color = self.color orelse {
			rl.drawRectangleLinesEx(rect, 2, rl.Color.black);
			return;
		};

		rl.drawRectangleRec(rect, color);
		rl.drawRectangleLinesEx(rect, 2, rl.Color.black);
	}
};

pub const Board = struct{
	size: ?tetromino.Vec2 = null,
	blocks: ?[]Block = null,
	allocator: std.mem.Allocator,
	tetromino: ?[5]tetromino.Tetromino = null,

	fn sizeInBlocks(self: Board) tetromino.Vec2 {
		return tetromino.Vec2{
			.x = self.size.?.x / tetromino.tile_size,
			.y = self.size.?.y / tetromino.tile_size,
		};
	}

	fn submitToBoard(self: *Board) void {
		const curr_tetromino = self.tetromino.?[0];
		const data = curr_tetromino.data;
		const pos = curr_tetromino.position.?;
		const blocks = &self.blocks.?;

		for (0.., data) |index, block| {
			if (block == 0) continue;
			const index_x = @as(i16, @intCast(index % 4)) + @as(i16, @intFromFloat(pos.x));
			const usize_x = @as(usize, @intCast(index_x));
			const index_y = @as(i16, @intCast(index / 4)) + @as(i16, @intFromFloat(pos.y));
			const usize_y = @as(usize, @intCast(index_y));
			blocks.*[usize_y * @as(usize, @intFromFloat(self.sizeInBlocks().x)) + usize_x].color = curr_tetromino.color;
		}
	}

	fn createNewTetromino(prng: *std.rand.DefaultPrng) tetromino.Tetromino {
		const random = prng.random().intRangeAtMost(u8, 0, tetromino.possible_shapes.len-1);
		var new_tetromino = tetromino.possible_shapes[random];
		new_tetromino.position = tetromino.Vec2{.x = 1, .y = 0};

		return new_tetromino;
	}

	fn reloadTetrominoArray(self: *Board, new_tetromino: tetromino.Tetromino) void {
		var new_arr = [_]tetromino.Tetromino{tetromino.possible_shapes[0]} ** 5;
		for (0..4) |index| {
			new_arr[index] = self.tetromino.?[index+1];
		}
		new_arr[4] = new_tetromino;
		self.tetromino = new_arr;
	}

	fn checkFinishedRows(self: *Board) void {
		var num_of_finished: usize = 0;
		for (0..@as(usize, @intFromFloat(self.sizeInBlocks().y))) |index_y| {
			const reverse_y = @as(usize, @intFromFloat(self.sizeInBlocks().y)) - index_y - 1;
			var noNullBlocks: bool = true;
			for (0..@as(usize, @intFromFloat(self.sizeInBlocks().x))) |index_x| {
				std.debug.print("{any}", .{self.blocks.?[reverse_y * @as(usize, @intFromFloat(self.sizeInBlocks().x)) + index_x].color});
				if (self.blocks.?[reverse_y * @as(usize, @intFromFloat(self.sizeInBlocks().x)) + index_x].color == null) {
					noNullBlocks = false;
					break;
				}
			}
			if (noNullBlocks == true) {
				num_of_finished += 1;
			}
		}
		// chyba trzeba to zamienić na numery linii które są ukończone
		std.debug.print("FINISHED:{d}\n", .{num_of_finished});
		if (num_of_finished == 0) return;
	}

	pub fn init(self: *Board, prng: *std.rand.DefaultPrng, board_size: tetromino.Vec2) !void {
		self.size = board_size;
		self.tetromino = [_]tetromino.Tetromino{tetromino.possible_shapes[0]} ** 5;

		for (0..5) |index| {
			self.tetromino.?[index] = Board.createNewTetromino(prng);
		}

		const block_count: u32 = @as(u32, @intFromFloat(self.sizeInBlocks().x)) * @as(u32, @intFromFloat(self.sizeInBlocks().y));
		self.blocks = try self.allocator.alloc(Block, block_count);
		errdefer self.allocator.free(self.blocks);

		for (self.blocks.?) |*block| {
			block.color = null;
		}
	}

	pub fn draw(self: Board) void {
		for (0.., self.blocks.?) |index, block| {
			const x = index % @as(usize, @intFromFloat(self.sizeInBlocks().x));
			const y = index / @as(usize, @intFromFloat(self.sizeInBlocks().x));
			block.draw(tetromino.Vec2{.x = @floatFromInt(x), .y = @floatFromInt(y)});
		}
		self.tetromino.?[0].draw();
	}

	pub fn moveTetromino(self: *Board, prng: *std.rand.DefaultPrng, direction: tetromino.Direction ) void {
		var block = &self.tetromino.?[0];

		const coord = block.getNonBlankLine(direction) catch return;
		const f_coord = @as(f16, @floatFromInt(coord));

		var position = &block.position.?;

		std.debug.print("LINE: {!d}\n", .{block.getNonBlankLine(direction)});
		std.debug.print("POS X={d} Y={d}\n", .{position.x, position.y});

		switch (direction) {
			tetromino.Direction.Left => {
				if (position.x + f_coord > 0) {
					position.x -= 1;
				}
			},
			tetromino.Direction.Right => {
				if (position.x + f_coord + 1 < self.sizeInBlocks().x) {
					position.x += 1;
				}
			},
			tetromino.Direction.Down => {
				if (position.y + f_coord + 1 < self.sizeInBlocks().y - 1) {
					position.y += 1;
				} else {
					self.submitToBoard();
					self.reloadTetrominoArray(Board.createNewTetromino(prng));
					self.checkFinishedRows();
				}
			}
		}
	}

	pub fn rotateTetromino(self: *Board) void {
		self.tetromino.?[0].rotate();
	}

	pub fn deinit(self: *Board) void {
		self.allocator.free(self.blocks.?);
	}
};
