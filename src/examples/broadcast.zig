const std = @import("std");
const alphazig = @import("alphazig");
const common = @import("./common_types.zig");

const Engine = alphazig.Engine;
const CandlesticksActor = common.CandlesticksActor;
const CandlesticksMessage = common.CandlesticksMessage;
const Candlestick = common.Candlestick;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, "candlesticks", allocator);

    engine.broadcast(CandlesticksMessage, &CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
}
