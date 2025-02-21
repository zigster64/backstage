const std = @import("std");
const inbox = @import("inbox.zig");

const assert = std.debug.assert;
const Inbox = inbox.Inbox;

pub const ActorInterface = struct {
    ptr: *anyopaque,
    receiveFnPtr: *const fn (ptr: *anyopaque, msg: *const anyopaque) void,

    inbox: *Inbox,

    pub fn init(
        allocator: std.mem.Allocator,
        obj: anytype,
        capacity: usize,
        comptime receiveFn: fn (ptr: @TypeOf(obj), msg: *const anyopaque) void,
    ) !ActorInterface {
        const T = @TypeOf(obj);
        const impl = struct {
            fn receive(ptr: *anyopaque, msg: *const anyopaque) void {
                const self = @as(T, @ptrCast(@alignCast(ptr)));
                receiveFn(self, msg);
            }
        };

        return .{
            .ptr = obj,
            .receiveFnPtr = impl.receive,
            .inbox = try Inbox.init(allocator, capacity),
        };
    }

    pub fn receive(self: ActorInterface) void {
        self.inbox.receive(self.ptr, null);
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
