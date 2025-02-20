const std = @import("std");
const alphazig = @import("alphazig");
const common = @import("./common_types.zig");
const testing = std.testing;

const Engine = alphazig.Engine;
const CandlesticksActor = common.CandlesticksActor;
const CandlesticksMessage = common.CandlesticksMessage;
const OtherUnionMessage = common.OtherUnionMessage;
const Candlestick = common.Candlestick;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, .{
        .id = "candlesticks",
    });

    const message = CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } };
    try engine.broadcast(message);
}

test "broadcast - can send CandlesticksMessage to actor" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, .{
        .id = "candlesticks",
    });

    const message = CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } };
    try engine.broadcast(message);
}

test "broadcast - can broadcast OtherUnionMessage to actor" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, .{
        .id = "candlesticks",
    });

    const message = OtherUnionMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } };
    try engine.broadcast(message);
}

test "broadcast - can broadcast non-union message to actor" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, .{
        .id = "candlesticks",
    });

    const message = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 };
    try engine.broadcast(message);
}

test "broadcast - broadcasting with no actors is handled gracefully" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    const message = CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } };
    try engine.broadcast(message);
}
