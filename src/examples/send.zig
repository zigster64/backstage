const std = @import("std");
const alphazig = @import("alphazig");
const common = @import("./common_types.zig");

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

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, "candlesticks", allocator);

    // Able to send and receive the message the actor is listening for
    engine.send(CandlesticksMessage, "candlesticks", &CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
    // Able to send and receive the message part of a union that the actor is not listening for
    engine.send(OtherUnionMessage, "candlesticks", &OtherUnionMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
    // Able to send and receive message with a type that is not a union
    engine.send(Candlestick, "candlesticks", &Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 });
}
