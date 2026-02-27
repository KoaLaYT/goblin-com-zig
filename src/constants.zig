const std = @import("std");

pub const DISPLAY_WIDTH = 80;
pub const DISPLAY_HEIGHT = 24;
pub const MAP_WIDTH = 60;
pub const MAP_HEIGHT = 24;

pub const ARROW_U = 321;
pub const ARROW_D = 322;
pub const ARROW_L = 324;
pub const ARROW_R = 323;
pub const ARROW_UL = 305;
pub const ARROW_DL = 308;
pub const ARROW_UR = 309;
pub const ARROW_DR = 310;

pub const FPS = 15;
pub const PERIOD = std.time.us_per_s / FPS;
