const std = @import("std");
const assert = std.debug.assert;
const msg = @import("message.zig");

const MessageInterface = msg.MessageInterface;

pub const ActorInterface = struct {
    ptr: *anyopaque,
    receiveFnPtr: *const fn (ptr: *anyopaque) void,

    pub fn init(
        obj: anytype,
        comptime receiveFn: fn (ptr: @TypeOf(obj)) void,
    ) ActorInterface {
        const T = @TypeOf(obj);
        const impl = struct {
            fn receive(ptr: *anyopaque) void {
                const self = @as(T, @ptrCast(@alignCast(ptr)));
                receiveFn(self);
            }
        };

        return .{
            .ptr = obj,
            .receiveFnPtr = impl.receive,
        };
    }

    pub fn receive(self: ActorInterface) void {
        self.receiveFnPtr(
            self.ptr,
        );
    }
};
