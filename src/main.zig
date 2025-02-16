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

    const candlestickActor = try CandlesticksActor.init(allocator);
    defer candlestickActor.deinit(allocator);

    // const testActor = ActorInterface.init(candlestickActor, receiveWrapper);

    try engine.spawnActor(CandlesticksActor, Candlestick, "candlesticks", allocator);

    engine.send("candlesticks", &Candlestick{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 });
}

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

    /// The concrete receive function.
    /// Note: It expects a *Candlestick, not a *anyopaque.
    pub fn receive(_: *CandlesticksActor, message: *const Candlestick) void {
        std.debug.print("Received Candlestick:\n  open: {}\n  high: {}\n  low: {}\n  close: {}\n", .{ message.open, message.high, message.low, message.close });
        // (For example, you could append the candlestick to a list here.)
    }
};

const Candlestick = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};
