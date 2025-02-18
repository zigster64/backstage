const std = @import("std");
const eng = @import("../engine.zig");
const act = @import("../actor.zig");
const msg = @import("../message.zig");
const common = @import("./commonTypes.zig");
const Engine = eng.Engine;

const CandlesticksActor = common.CandlesticksActor;
const CandlesticksMessage = common.CandlesticksMessage;
const Candlestick = common.Candlestick;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var engine = Engine.init(allocator);

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, "candlesticks", allocator);

    engine.broadcast(CandlesticksMessage, &CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
    // engine.broadcast(WrongMessage, &WrongMessage{.test_msg = WrongTestMessage{.example = "test"}});
    // engine.send(CandlesticksMessage, "candlesticks", &CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
    // engine.send(WrongMessage, "candlesticks", &WrongMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
}
