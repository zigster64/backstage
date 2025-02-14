const std = @import("std");
const eng = @import("engine.zig");
const act = @import("actor.zig");
const msg = @import("message.zig");

const Engine = eng.Engine;
const ActorInterface = act.ActorInterface;
const Message = msg.Message;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var engine = Engine.init(allocator);

    const candlestickActor = try CandlesticksActor.init(allocator);
    defer candlestickActor.deinit(allocator);

    try engine.spawn("candlesticks", candlestickActor);

    engine.send("candlesticks", Message(Candlestick){ .data = Candlestick{
        .open = 100.0,
        .high = 100.0,
        .low = 100.0,
        .close = 100.0,
    } });
}

const CandlesticksActor = struct {
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

    pub fn receive(self: *CandlesticksActor, message: Message(Candlestick)) void {
        self.candlesticks.append(message.data) catch unreachable;
    }
};

const Candlestick = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};
