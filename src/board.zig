const tetromino = @import("tetromino.zig");
const rl = @import("raylib");
const std = @import("std");

const highscores_filename = "highscores.txt";
const highscores_count = 10;

const Block = struct {
	color: ?rl.Color = null,

	fn draw(self: Block, position: tetromino.Vec2(usize)) void {
		const rect = rl.Rectangle{
				.x = @floatFromInt(position.x * tetromino.tile_size),
				.y = @floatFromInt(position.y * tetromino.tile_size),
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
	size: ?tetromino.Vec2(usize) = null,
	blocks: ?[]Block = null,
	allocator: std.mem.Allocator,
	tetromino: ?[5]tetromino.Tetromino = null,
	game_speed: f16 = 1.0,
	score: i16 = 0,
	highscores: [highscores_count]u16 = undefined,
	game_over: bool = false,

	fn sizeInBlocks(self: Board) tetromino.Vec2(usize) {
		return tetromino.Vec2(usize){
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
			const index_x = @as(usize, @intCast(@as(i16, @intCast(index % 4)) + pos.x));
			const index_y = @as(usize, @intCast(@as(i16, @intCast(index / 4)) + pos.y));
			blocks.*[index_y * self.sizeInBlocks().x + index_x].color = curr_tetromino.color;
		}
	}

	fn createNewTetromino(self: Board, prng: *std.rand.DefaultPrng) tetromino.Tetromino {
		const random = prng.random().intRangeAtMost(u8, 0, tetromino.possible_shapes.len-1);
		var new_tetromino = tetromino.possible_shapes[random];
		new_tetromino.position = tetromino.Vec2(i16){.x = @divTrunc(@as(i16, @intCast(self.sizeInBlocks().x)), 2) - 2, .y = 0};

		return new_tetromino;
	}

	fn reloadTetrominoArray(self: *Board, new_tetromino: tetromino.Tetromino) void {
		const array_size: usize = 5;
		var new_arr = [_]tetromino.Tetromino{tetromino.possible_shapes[0]} ** array_size;
		for (0..array_size-1) |index| {
			new_arr[index] = self.tetromino.?[index+1];
		}
		new_arr[array_size-1] = new_tetromino;
		self.tetromino = new_arr;
	}

	fn checkFinishedRows(self: *Board) !void {
		var finished_rows = try self.allocator.alloc(bool, self.sizeInBlocks().y);
		var finished_rows_count: usize = 0;
		defer self.allocator.free(finished_rows);

		for (0..self.sizeInBlocks().y) |index_y| {
			var noNullBlocks: bool = true;
			for (0..self.sizeInBlocks().x) |index_x| {
				if (self.blocks.?[index_y * self.sizeInBlocks().x + index_x].color == null) {
					noNullBlocks = false;
					break;
				}
			}
			finished_rows[index_y] = noNullBlocks;
			finished_rows_count += @intFromBool(noNullBlocks);
		}

		for(0..finished_rows.len) |row_index| {
			if (!finished_rows[row_index]) {
				continue;
			}
			std.debug.print("FINISHED ROW: {d}\n", .{row_index});

			// probably unnecessary, maybe for an animation
			for (0..self.sizeInBlocks().x) |index_x| {
				self.blocks.?[row_index * self.sizeInBlocks().x + index_x] = Block{.color = null};
			}

			for (0..row_index) |temp| {
				const copy_index = row_index - temp;
				for (0..self.sizeInBlocks().x) |index_x| {
					const old_index = (copy_index - 1) * self.sizeInBlocks().x + index_x;
					const new_index = copy_index * self.sizeInBlocks().x + index_x;
					self.blocks.?[new_index] = self.blocks.?[old_index];
				}
			}
		}

		self.score += @intFromFloat(self.game_speed * @as(f16, @floatFromInt(finished_rows_count * finished_rows_count)) * 10);
	}

	fn writeScores(self: Board) !void {
		if (self.score == 0) return;

		const file = try std.fs.cwd().createFile(highscores_filename, .{});
		defer file.close();

		var temp_highscores = [_]u16{0} ** (highscores_count+1);
		for (0..temp_highscores.len-1) |index| {
			temp_highscores[index] = self.highscores[index];
		}
		temp_highscores[temp_highscores.len-1] = @intCast(self.score);
		std.mem.sort(u16, &temp_highscores, {}, comptime std.sort.desc(u16));

		for (temp_highscores) |item| {
			if (item == 0) continue;
			try file.writer().writeAll(rl.textFormat("Score %i\n", .{item}));
		}
	}

	fn loadScores(self: *Board) !void {
		var file = try std.fs.cwd().openFile(highscores_filename, .{});
		defer file.close();

		var buf_reader = std.io.bufferedReader(file.reader());
		var in_stream = buf_reader.reader();

		var buf: [1024]u8 = undefined;
		var index: usize = 0;
		while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
			if (index >= self.highscores.len) break;

			const num = std.mem.indexOf(u8, &buf, " ");
			if (num) |num_index| {
				const fmt_num = std.fmt.parseInt(u16, line[num_index+1..], 10) catch continue;
				self.highscores[index] = fmt_num;
				index += 1;
			}
		}
		std.mem.sort(u16, &self.highscores, {}, comptime std.sort.desc(u16));
	}

	pub fn init(self: *Board, prng: *std.rand.DefaultPrng, board_size: tetromino.Vec2(usize)) !void {
		self.size = board_size;
		self.tetromino = [_]tetromino.Tetromino{tetromino.possible_shapes[0]} ** 5;

		self.highscores = [_]u16{0} ** highscores_count;

		self.loadScores() catch |err| {
			std.debug.print("{any}\n", .{err});
		};

		for (0..5) |index| {
			self.tetromino.?[index] = self.createNewTetromino(prng);
		}

		const block_count: u32 = @as(u32, @intCast(self.sizeInBlocks().x)) * @as(u32, @intCast(self.sizeInBlocks().y));
		self.blocks = try self.allocator.alloc(Block, block_count);
		errdefer self.allocator.free(self.blocks);

		for (self.blocks.?) |*block| {
			block.color = null;
		}
	}

	pub fn draw(self: Board) void {
		for (0.., self.blocks.?) |index, block| {
			const x = index % self.sizeInBlocks().x;
			const y = index / self.sizeInBlocks().x;
			block.draw(tetromino.Vec2(usize){.x = x, .y = y});
		}
		self.tetromino.?[0].draw();


		// score text
		rl.drawText(
			rl.textFormat("Score: [%i]", .{self.score}),
			@as(i32, @intCast(self.sizeInBlocks().x)) * tetromino.tile_size + 100,
			@divTrunc(@as(i32, @intCast(self.sizeInBlocks().y)) * tetromino.tile_size, 2) - 100,
			30,
			rl.Color.black
		);

		// speed text
		rl.drawText(
			rl.textFormat("Speed: %.2f", .{self.game_speed}),
			@as(i32, @intCast(self.sizeInBlocks().x)) * tetromino.tile_size + 100,
			@divTrunc(@as(i32, @intCast(self.sizeInBlocks().y)) * tetromino.tile_size, 2) - 70,
			30,
			rl.Color.black
		);

		// highscores text
		for (0.., self.highscores) |index, highscore| {
			if (highscore == 0) break;

			rl.drawText(
				rl.textFormat("User: %i", .{highscore}),
				@as(i32, @intCast(self.size.?.x + 100)),
				@as(i32, @intCast(@divTrunc(self.size.?.y, 2) + index * 30)),
				30,
				rl.Color.black,
			);
		}

		// draw blocks in queue
		const block_gap: i16 = 120;
		for (0.., self.tetromino.?[1..]) |index, block| {
			block.drawMiniature(tetromino.Vec2(i16){
				.x = @as(i16, @intCast(self.sizeInBlocks().x)) * tetromino.tile_size + 70 + (@as(i16, @intCast(index)) * block_gap),
				.y = 100,
			});
		}
	}

	pub fn moveTetromino(self: *Board, prng: *std.rand.DefaultPrng, direction: tetromino.Direction ) void {
		var block = &self.tetromino.?[0];

		const coord = block.getNonBlankLine(direction) catch return;

		var pos = &block.position.?;

// 		std.debug.print("LINE: {!d} POS X={d} Y={d}\n", .{block.getNonBlankLine(direction), pos.x, pos.y});

		switch (direction) {
			tetromino.Direction.Left => {
				var canMove: bool = true;
				for (0..4) |index_y| {
					// compare parallel blocks to the left of the first non blank line
					if (pos.y + @as(i16, @intCast(index_y)) + 1 > self.sizeInBlocks().y) {
						continue;
					}
					for (coord..4) |index_x| {
						const tetromino_pos = index_y * 4 + index_x;
						if (block.data[tetromino_pos] == 0 or pos.x + @as(i16, @intCast(index_x)) - 1 < 0) continue;

						const left_block_pos = (pos.y + @as(i16, @intCast(index_y))) * @as(i16, @intCast(self.sizeInBlocks().x)) + pos.x + @as(i16, @intCast(index_x)) - 1;
						if (self.blocks.?[@intCast(left_block_pos)].color != null) {
							canMove = false;
							break;
						}
					}

				}
				if (pos.x + @as(i16, @intCast(coord)) > 0 and canMove) {
					pos.x -= 1;
				}
			},
			tetromino.Direction.Right => {
				var canMove: bool = true;
				for (0..4) |index_y| {
					// compare parallel blocks to the left of the first non blank line
					if (pos.y + @as(i16, @intCast(index_y)) + 1 > self.sizeInBlocks().y) {
						continue;
					}
					for (0..4) |index_x| {
						const tetromino_pos = index_y * 4 + index_x;
						if (block.data[tetromino_pos] == 0 or pos.x + @as(i16, @intCast(index_x)) + 1 > self.sizeInBlocks().x - 1) continue;

						const right_block_pos = (pos.y + @as(i16, @intCast(index_y))) * @as(i16, @intCast(self.sizeInBlocks().x)) + pos.x + @as(i16, @intCast(index_x)) + 1;
						if (self.blocks.?[@intCast(right_block_pos)].color != null) {
							canMove = false;
							break;
						}
					}
				}
				if (pos.x + @as(i16, @intCast(coord)) + 1 < self.sizeInBlocks().x and canMove) {
					pos.x += 1;
				}
			},
			tetromino.Direction.Down => {
				var canMove: bool = true;
				outer: for (0..4) |index_x| {
					// compare parallel blocks to the left of the first non blank line
					if (pos.x + @as(i16, @intCast(index_x)) > self.sizeInBlocks().x or pos.x + @as(i16, @intCast(index_x)) < 0) {
						continue;
					}
					for (0..4) |index_y| {
						const tetromino_pos = index_y * 4 + index_x;

						if (block.data[tetromino_pos] == 0 or pos.y + @as(i16, @intCast(index_y)) + 1 > self.sizeInBlocks().y - 1) continue;

						const down_block_pos = (pos.y + @as(i16, @intCast(index_y)) + 1) * @as(i16, @intCast(self.sizeInBlocks().x)) + pos.x + @as(i16, @intCast(index_x));

						if (self.blocks.?[@intCast(down_block_pos)].color != null) {
							if (pos.y + @as(i16, @intCast(index_y)) <= 1) {
								self.game_over = true;
								self.writeScores() catch |err| std.debug.print("ERROR WHILE TRYING TO RECORD SCORE: {any}\n", .{err});
							}
							canMove = false;
							break :outer;
						}
					}
				}

				if (pos.y + @as(i16, @intCast(coord)) + 1 < self.sizeInBlocks().y and canMove) {
					pos.y += 1;
				} else {
					self.game_speed *= 1.01;
					self.submitToBoard();
					self.reloadTetrominoArray(self.createNewTetromino(prng));
					self.checkFinishedRows() catch return;
				}
			}
		}
	}

	pub fn rotateTetromino(self: *Board) void {
		const tetromino_data = self.tetromino.?[0].data;
		const tetromino_pos = self.tetromino.?[0].position.?;

		var data = [_]u1{0} ** 16;
		for (0..4) |index_x| {
			for (0..4) |index_y| {
				const rotated_x: usize = (tetromino_data.len / 4 - index_y - 1);
				const rotated_y: usize = index_x;

				const rotated_index = rotated_y * 4 + rotated_x;

				if (@as(i16, @intCast(rotated_x)) + tetromino_pos.x < 0) return;
				const board_x: usize = @as(usize, @intCast(@as(i16, @intCast(rotated_x)) + tetromino_pos.x));
				const board_y: usize = @as(usize, @intCast(tetromino_pos.y)) + rotated_y;

				if (tetromino_data[index_y * 4 + index_x] == 1) {
					if (board_x > self.sizeInBlocks().x-1 or board_y > self.sizeInBlocks().y-1 or self.blocks.?[board_y * self.sizeInBlocks().x + board_x].color != null) {
						return;
					}
				}
				data[rotated_index] = tetromino_data[index_y * 4 + index_x];
			}
		}
		self.tetromino.?[0].data = data;
	}

	pub fn restart(self: *Board) void {
		for (self.blocks.?) |*block| {
			block.color = null;
		}
		self.game_over = false;
		self.game_speed = 1.0;
		self.score = 0;
		self.highscores = [_]u16{0} ** highscores_count;
		self.loadScores() catch |err| {
			std.debug.print("{any}\n", .{err});
		};
	}

	pub fn deinit(self: *Board) void {
		self.allocator.free(self.blocks.?);
	}
};
