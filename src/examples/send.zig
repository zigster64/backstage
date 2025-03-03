const std = @import("std");
const alphazig = @import("alphazig");
const testing = std.testing;
const concurrency = alphazig.concurrency;

const Engine = alphazig.Engine;
const Context = alphazig.Context;
const ActorInterface = alphazig.ActorInterface;
const Coroutine = concurrency.Coroutine;
const Scheduler = concurrency.Scheduler;
const Channel = concurrency.Channel;
const EmptyArgs = concurrency.EmptyArgs;
pub fn main() !void {
    concurrency.run(mainRoutine);
}
pub fn mainRoutine(_: *Scheduler, _: EmptyArgs) !void {
    // ctx.add(1);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    const candlestick_receiver = try engine.spawnActor(CandlestickReceiver, CanclestickReveiverMessage, .{
        .id = "candlestick_receiver",
    });
    _ = candlestick_receiver;
    // try engine.send("candlesticks", CandlesticksMessage{ .candlestick = .{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
    // try candlestick_receiver.send(CanclestickReveiverMessage{ .candlestick = .{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });

    const candlestick_sender = try engine.spawnActor(CandlestickSender, CandlestickSenderMessage, .{
        .id = "candlestick_sender",
    });
    try candlestick_sender.send(CandlestickSenderMessage{ .init = .{} });
    try candlestick_sender.send(CandlestickSenderMessage{ .start_sending = .{} });
    // TODO It somehow works if I uncomment this STRANGE
    // _ = try engine.spawnActor(CandlestickSender, CandlestickSenderMessage, .{
    //     .id = "candlestick_sender_3",
    // });
    // TODO ITS BECAUSE MEMORY GETS DIGCARGED, probably the parameters
    while (true) {
        std.time.sleep(1000000000);
    }
    // candlestick_receiver.deinit();
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

// This is an example of a message that can be sent to the CandlesticksActor.
pub const CanclestickReveiverMessage = union(enum) {
    candlestick: Candlestick,
};

pub const Candlestick = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};

pub const CandlestickReceiver = struct {
    candlesticks: std.ArrayList(Candlestick),

    pub fn init(ctx: *Context, arena: *std.heap.ArenaAllocator) !*@This() {
        _ = ctx;
        const allocator = arena.allocator();
        const self = try allocator.create(@This());
        self.* = .{
            .candlesticks = std.ArrayList(Candlestick).init(allocator),
        };
        return self;
    }

    pub fn receive(_: *@This(), message: *const CanclestickReveiverMessage) !void {
        switch (message.*) {
            .candlestick => |candlestick| {
                std.debug.print("Received Candlestick:\n  open: {}\n  high: {}\n  low: {}\n  close: {}\n", .{ candlestick.open, candlestick.high, candlestick.low, candlestick.close });
            },
        }
    }
};

pub const CandlestickSenderMessage = union(enum) {
    init: struct {},
    start_sending: struct {},
};

pub const CandlestickSender = struct {
    ctx: *Context,
    candlestick_receiver: ?*ActorInterface = undefined,
    counter: u32 = 0,
    pub fn init(ctx: *Context, arena: *std.heap.ArenaAllocator) !*@This() {
        const allocator = arena.allocator();
        const self = try allocator.create(@This());
        self.* = .{
            .ctx = ctx,
        };
        return self;
    }

    pub fn receive(self: *@This(), message: *const CandlestickSenderMessage) !void {
        switch (message.*) {
            .init => {
                // self.candlestick_receiver = self.ctx.getActor("candlestick_receiver");
            },
            .start_sending => {
                // while (true) {
                // self.counter += 1;
                // if (self.candlestick_receiver) |receiver| {
                //     try receiver.send(CanclestickReveiverMessage{ .candlestick = .{ .open = 1.0, .high = 2.0, .low = 3.0, .close = 4.0 } });
                // }
                _ = try self.ctx.spawnChildActor(CandlestickSender, CandlestickSenderMessage, .{
                    .id = "candlestick_sender_2",
                });
                // std.debug.print("Sent {}\n", .{self.counter});
                // }
            },
        }
    }
};
