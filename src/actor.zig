const std = @import("std");
const inbox = @import("inbox.zig");
const concurrency = @import("concurrency/root.zig");

const assert = std.debug.assert;
const Inbox = inbox.Inbox;
const Coroutine = concurrency.Coroutine;
const Context = concurrency.Context;

pub const ActorInterface = struct {
    ptr: *anyopaque,
    receiveFnPtr: *const fn (ptr: *anyopaque, msg: *const anyopaque) void,

    inbox: Inbox,

    pub fn init(
        _: std.mem.Allocator,
        obj: anytype,
        capacity: usize,
        comptime receiveFn: fn (ptr: @TypeOf(obj), msg: *const anyopaque) void,
        comptime MsgType: type,
    ) !ActorInterface {
        const T = @TypeOf(obj);
        const impl = struct {
            fn receive(ptr: *anyopaque, msg: *const anyopaque) void {
                const self = @as(T, @ptrCast(@alignCast(ptr)));
                receiveFn(self, msg);
            }
        };

        const receiveRoutine = struct {
            fn routine(ctx: *Context, args: struct { self: ActorInterface }) !void {
                var msg: MsgType = undefined;
                while (true) {
                    try args.self.inbox.receive(&msg);
                    std.debug.print("received message {}\n", .{msg});
                    ctx.yield();
                }
            }
        }.routine;

        const instance = ActorInterface{
            .ptr = obj,
            .receiveFnPtr = impl.receive,
            .inbox = try Inbox.init(MsgType, capacity),
        };

        var ctx = Context.init(null);
        Coroutine(receiveRoutine).go(&ctx, .{ .self = instance });

        return instance;
    }

    pub fn send(self: *const ActorInterface, msg: anytype) !void {
        try self.inbox.send(msg);
    }
};

pub fn makeReceiveFn(
    comptime ActorType: type,
    comptime MsgType: type,
) fn (actor: *ActorType, message: *const anyopaque) void {
    return struct {
        fn receive(actor: *ActorType, message: *const anyopaque) void {
            const castMsg = @as(*const MsgType, @ptrCast(@alignCast(message)));
            ActorType.receive(actor, castMsg);
        }
    }.receive;
}

pub const Candlestick = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};
