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
        // TODO This is incorrect
        // var msg: ?*const anyopaque = null;
        // Assume inbox.receive returns an error union or a boolean that indicates success.
        var candlestick: Candlestick = undefined;

        const result = self.inbox.receive(&candlestick);
        std.debug.print("result {}\n", .{result});
        std.debug.print("candlestick {}\n", .{candlestick});
        // if (result) |actualMsg| {
        //     // Now that we have a valid message pointer, call the actor's receive function.
        //     self.receiveFnPtr(self.ptr, actualMsg);
        // } else {
        //     // Handle the case where no message was available or an error occurred.
        //     // For example, log an error or simply return.
        // }
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
