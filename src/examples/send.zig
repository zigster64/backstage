const std = @import("std");
const alphazig = @import("alphazig");
const common = @import("./common_types.zig");
const testing = std.testing;
const concurrency = alphazig.concurrency;

const Engine = alphazig.Engine;
const CandlesticksActor = common.CandlesticksActor;
const StartIntervalMessage = common.StartIntervalMessage;
const CandlesticksMessage = common.CandlesticksMessage;
const OtherUnionMessage = common.OtherUnionMessage;
const Candlestick = common.Candlestick;
const Coroutine = concurrency.Coroutine;
const Context = concurrency.Context;

pub fn main() !void {
    concurrency.init(Coroutine.spawn(mainRoutine));
}
pub fn mainRoutine() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, .{
        .id = "candlesticks",
    });
}

test "send - can send CandlesticksMessage to actor" {
    // zeco.init();

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, .{
        .id = "candlesticks",
    });

    const message = CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } };
    try engine.send("candlesticks", message);
}

test "send - can send OtherUnionMessage to actor" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, .{
        .id = "candlesticks",
    });

    const message = OtherUnionMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } };
    try engine.send("candlesticks", message);
}

test "send - can send non-union message to actor" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, .{
        .id = "candlesticks",
    });

    const message = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 };
    try engine.send("candlesticks", message);
}

test "send - sending to non-existent actor is handled gracefully" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    const message = CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } };
    try engine.send("non-existent", message);
}

test "send - can send StartIntervalMessage to actor" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, .{
        .id = "candlesticks",
    });

    const message = StartIntervalMessage{ .interval_ms = 1000 };
    try engine.send("candlesticks", message);
}
