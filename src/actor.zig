const std = @import("std");

const Allocator = std.mem.Allocator;

pub const ActorInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        // Add your required function pointers here
        // For example:
        receive: *const fn (ptr: *anyopaque, message: anytype) void,
        // Add more required methods as needed
    };

    pub fn init(actor: *anyopaque) ActorInterface {
        const T = @TypeOf(actor);

        const actor_ptr = actor;
        const vtable = comptime &VTable{
            .receive = struct {
                fn receive(ptr: *anyopaque, message: anytype) void {
                    const self = @as(*T, @ptrCast(@alignCast(ptr)));
                    self.receive(message);
                }
            }.receive,
            // Initialize other vtable functions similarly
        };

        return .{
            .ptr = @ptrCast(actor_ptr),
            .vtable = vtable,
        };
    }

    pub fn receive(self: ActorInterface, message: anytype) void {
        self.vtable.receive(self.ptr, message);
    }
};
