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

    try engine.spawnActor(allocator, CandlesticksActor, CandlesticksMessage, "candlesticks");

    // Able to send the message the actor is listening for
    engine.send( "candlesticks", CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
    // Able to send the message part of a union that the actor is not listening for
    engine.send( "candlesticks", OtherUnionMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
    // Able to send message with
    engine.send( "candlesticks", Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 });
}

test "send - can send CandlesticksMessage to actor" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(allocator, CandlesticksActor, CandlesticksMessage, "candlesticks");

    const message = CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } };
    engine.send( "candlesticks", message);
}

test "send - can send OtherUnionMessage to actor" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(allocator, CandlesticksActor, CandlesticksMessage, "candlesticks");

    const message = OtherUnionMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } };
    engine.send( "candlesticks", message);
}

test "send - can send non-union message to actor" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    try engine.spawnActor(allocator, CandlesticksActor, CandlesticksMessage, "candlesticks");

    const message = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 };
    engine.send( "candlesticks", message);
}

test "send - sending to non-existent actor is handled gracefully" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    const message = CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } };
    engine.send( "non-existent", message);
}
