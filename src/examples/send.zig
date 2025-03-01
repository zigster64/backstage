const std = @import("std");
const alphazig = @import("alphazig");
const testing = std.testing;
const concurrency = alphazig.concurrency;

const Engine = alphazig.Engine;
const Coroutine = concurrency.Coroutine;
const Context = concurrency.Context;
const Channel = concurrency.Channel;
pub fn main() !void {
    concurrency.run(mainRoutine);
}
pub fn mainRoutine(_: *Context, _: void) !void {
    // ctx.add(1);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    const candlesticks_actor = try engine.spawnActor(CandlesticksActor, CandlesticksMessage, .{
        .id = "candlesticks",
    });
    // _ = candlesticks_actor;
    try engine.send("candlesticks", CandlesticksMessage{ .candlestick = .{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
    try candlesticks_actor.send(CandlesticksMessage{ .candlestick = .{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
    // candlesticks_actor.send(.{ .candlestick = .{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
    // candlesticks_actor.start_receiving();
    // var chan = try Channel.init(i32, 0);
    // defer chan.deinit();
    // try chan.retain();

    // var new_ctx = Context.init(null);
    // Coroutine.spawn(&new_ctx, testSender, .{ .chan = chan });
    // Coroutine.spawn(&new_ctx, testReceiver, .{ .chan = chan });
    // Coroutine.spawn(&new_ctx, testReceiver, .{ .chan = chan });
}

// pub fn testReceiver(_: *Context, args: struct { chan: Channel }) !void {
//     while (true) {
//         var value: i32 = undefined;
//         try args.chan.receive(&value);
//         std.debug.print("Received: {}\n", .{value});
//     }
// }
// pub fn testSender(_: *Context, args: struct { chan: Channel }) !void {
//     _ = args.chan;

//     var value: i32 = 1;
//     while (true) {
//         std.time.sleep(1000000000);
//         value += 1;
//         _ = try args.chan.broadcast(value);
//         std.debug.print("Sent: {}\n", .{value});
//     }
// }

pub const StartIntervalMessage = struct {
    interval_ms: u64,
};

// This is an example of a message that can be sent to the CandlesticksActor.
pub const CandlesticksMessage = union(enum) {
    start_interval: StartIntervalMessage,
    candlestick: Candlestick,
};

pub const Candlestick = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};

// This is an example of an unspecific union being able to be sent to the CandlesticksActor.
pub const OtherUnionMessage = union(enum) {
    candlestick: Candlestick,
};

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
            .start_interval => |start_interval| {
                std.debug.print("Received StartIntervalMessage:\n  interval_ms: {}\n", .{start_interval.interval_ms});
            },
            .candlestick => |candlestick| {
                std.debug.print("Received Candlestick:\n  open: {}\n  high: {}\n  low: {}\n  close: {}\n", .{ candlestick.open, candlestick.high, candlestick.low, candlestick.close });
            },
        }
    }
};
