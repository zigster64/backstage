const std = @import("std");
const concurrency = @import("concurrency/root.zig");

const Channel = concurrency.Channel;
const Allocator = std.mem.Allocator;

pub const Inbox = struct {
    chan: Channel,

    pub fn init(comptime T: type, capacity: usize) !Inbox {
        var chan = try Channel.init(T, capacity * @sizeOf(T));
        errdefer chan.deinit();
        try chan.retain();
        return .{
            .chan = chan,
        };
    }

    pub fn deinit(self: *const Inbox) void {
        self.chan.deinit();
    }

    pub fn send(self: Inbox, message: anytype) !void {
        try self.chan.send(message);
    }

    pub fn receive(self: Inbox, value: anytype) !void {
        try self.chan.receive(value);
    }
};
