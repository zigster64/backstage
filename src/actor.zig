const std = @import("std");
const assert = std.debug.assert;
// const msg = @import("message.zig");

// const MessageInterface = msg.MessageInterface;


pub const ActorInterface = struct {
    ptr: *anyopaque,
    receiveFnPtr: *const fn (ptr: *anyopaque, msg: *const anyopaque) void,

    pub fn init(
        obj: anytype,
        comptime receiveFn: fn (ptr: @TypeOf(obj), msg: *const anyopaque) void,
    ) ActorInterface {
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
        };
    }

    pub fn receive(self: ActorInterface, msg: *const anyopaque) void {
        self.receiveFnPtr(
            self.ptr,
            msg,
        );
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