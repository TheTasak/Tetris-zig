const std  = @import("std");
const rl = @import("raylib");

const tetromino = @import("tetromino.zig");
const board = @import("board.zig");

pub const GameState = enum{
	GamePlaying,
	GameOver,
	GamePause,
};

pub const Game = struct{
	game_state: GameState = GameState.GamePlaying,
	board: *board.Board,
	screen_size: tetromino.Vec2(usize),

	pub fn update(self: *Game, prng: *std.rand.DefaultPrng, sumTime: *f32) void {
		const deltaTime: f32 = rl.getFrameTime();
        sumTime.* += deltaTime;

		if (self.board.game_over) {
			self.game_state = GameState.GameOver;
		}

		switch (self.game_state) {
			GameState.GamePlaying => {
				if (sumTime.* > 1 / self.board.game_speed) {
					self.board.moveTetromino(prng, tetromino.Direction.Down);
					sumTime.* = 0;
				}
			},
			GameState.GameOver => {
				return;
			},
			GameState.GamePause => {
				return;
			}
		}

	}

	pub fn handleInputs(self: *Game, prng: *std.rand.DefaultPrng) void {
		switch (self.game_state) {
			GameState.GamePlaying => {
				if (rl.isKeyPressed(rl.KeyboardKey.key_left)) {
					self.board.moveTetromino(prng, tetromino.Direction.Left);
				} else if (rl.isKeyPressed(rl.KeyboardKey.key_right)) {
					self.board.moveTetromino(prng, tetromino.Direction.Right);
				} else if (rl.isKeyDown(rl.KeyboardKey.key_down)) {
					self.board.moveTetromino(prng, tetromino.Direction.Down);
				} else if (rl.isKeyPressed(rl.KeyboardKey.key_up)) {
					self.board.rotateTetromino();
				} else if (rl.isKeyPressed(rl.KeyboardKey.key_p)) {
					self.game_state = GameState.GamePause;
				}
			},
			GameState.GameOver => {
				if (rl.isKeyPressed(rl.KeyboardKey.key_r)) {
					self.game_state = GameState.GamePlaying;
					self.board.restart();
				}
			},
			GameState.GamePause => {
				if (rl.isKeyPressed(rl.KeyboardKey.key_p)) {
					self.game_state = GameState.GamePlaying;
				}
			}
		}

	}

	pub fn draw(self: Game) void {
		rl.clearBackground(rl.Color.init(210, 219, 203, 200));

		switch (self.game_state) {
			GameState.GamePlaying => self.board.draw(),
			GameState.GamePause => {
				self.board.draw();
				rl.drawText("PAUSED", @as(i32, @intCast(self.screen_size.x)) - 150, 15, 30, rl.Color.black);
			},
			GameState.GameOver => {
				const screen_middle = tetromino.Vec2(i32){.x = @divTrunc(@as(i32, @intCast(self.screen_size.x)), 2), .y = @divTrunc(@as(i32, @intCast(self.screen_size.y)), 2)};
				if (self.board.score > self.board.highscores[0]) {
					rl.drawText("*** NEW HIGHSCORE ***", screen_middle.x - 200, screen_middle.y - 90, 35, rl.Color.red);
				}
				rl.drawText("GAME OVER", screen_middle.x - 70, screen_middle.y - 25, 30, rl.Color.black);
				rl.drawText(rl.textFormat("Score %i", .{self.board.score}), screen_middle.x - 70, screen_middle.y + 25, 30, rl.Color.black);
			}
		}
	}

	pub fn deinit(self: *Game) void {
		self.board.deinit();
	}
};
