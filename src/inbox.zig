const std = @import("std");
const concurrency = @import("concurrency/root.zig");

const Channel = concurrency.Channel;
const Allocator = std.mem.Allocator;

pub const Inbox = struct {
    chan: Channel,

    const Self = @This();
    pub fn init(comptime T: type, capacity: usize) !Self {
        // var chan = try Channel.init(T, capacity * @sizeOf(T));

        var chan = try Channel.init(T, capacity);
        errdefer chan.deinit();
        try chan.retain();
        return .{
            .chan = chan,
        };
    }

    pub fn deinit(self: *Self) void {
        self.chan.deinit();
    }

    pub fn send(self: *const Self, message: anytype) !void {
        try self.chan.send(message);
    }

    pub fn receive(self: *const Self, value: anytype) !void {
        try self.chan.receive(value);
    }
};
