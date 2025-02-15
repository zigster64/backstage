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

    const testActor = ActorInterface.init(candlestickActor, CandlesticksActor.receive);
    try engine.spawn("candlesticks", testActor);

    engine.send("candlesticks");
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

    pub fn receive(_: *CandlesticksActor) void {
        std.debug.print("Received message\n", .{});
        // if (message.get(Candlestick)) |candlestick| {
        //     self.candlesticks.append(candlestick) catch unreachable;
        // }
    }
};

const Candlestick = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};
