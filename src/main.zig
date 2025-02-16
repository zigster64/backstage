const std = @import("std");
const eng = @import("engine.zig");
const act = @import("actor.zig");
const msg = @import("message.zig");

const Engine = eng.Engine;
const ActorInterface = act.ActorInterface;
const MessageInterface = msg.MessageInterface;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var engine = Engine.init(allocator);

    try engine.spawnActor(CandlesticksActor, CandlesticksMessage, "candlesticks", allocator);

    engine.send("candlesticks", &CandlesticksMessage{ .candlestick = Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
    engine.send("candlesticks", &CandlesticksMessage{ .test_msg = TestMessage{ .example = "test" } });
}
// TODO: Actors should register themselves with the engine. When doing so they should provide what sort of messages they are interested in.
// The engine will then only send messages of the correct type to the actor.

// This is an example of a simple actor that receives messages and processes them.
pub const CandlesticksActor = struct {
    candlesticks: std.ArrayList(Candlestick),

    pub fn init(allocator: std.mem.Allocator) !*CandlesticksActor {
        const self = try allocator.create(CandlesticksActor);
        self.* = .{
            .candlesticks = std.ArrayList(Candlestick).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *CandlesticksActor, allocator: std.mem.Allocator) void {
        self.candlesticks.deinit();
        allocator.destroy(self);
    }

    pub fn receive(_: *CandlesticksActor, message: *const CandlesticksMessage) void {
        switch (message.*) {
            .candlestick => |candlestick| {
                std.debug.print("Received Candlestick:\n  open: {}\n  high: {}\n  low: {}\n  close: {}\n", .{ candlestick.open, candlestick.high, candlestick.low, candlestick.close });
            },
            .test_msg => |test_msg| {
                std.debug.print("Received Test Message:\n  example: {s}\n", .{test_msg.example});
            },
        }
    }
};

// This is an example of a message that can be sent to the CandlesticksActor.
pub const CandlesticksMessage = union(enum) {
    candlestick: Candlestick,
    test_msg: TestMessage,
};

const Candlestick = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};

const TestMessage = struct {
    example: []const u8,
};
