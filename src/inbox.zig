const std = @import("std");

const RingBuffer = std.RingBuffer;
const Allocator = std.mem.Allocator;

pub const Inbox = struct {
    ring_buffer: RingBuffer,

    pub fn init(allocator: Allocator, capacity: usize) !*Inbox {
        const inbox = try allocator.create(Inbox);
        inbox.ring_buffer = try RingBuffer.init(allocator, capacity);
        return inbox;
    }

    pub fn deinit(self: *Inbox) void {
        self.ring_buffer.deinit();
    }

    pub fn send(self: *Inbox, message: anytype) !void {
        const bytes = std.mem.asBytes(&message);
        try self.ring_buffer.writeSlice(bytes);
    }

    // TODO Make this like Golang does it, this is currently incorrect
    pub fn receive(self: *Inbox, value: anytype) bool {
        if (self.ring_buffer.read()) |byte| {
            value.* = byte;
            return true;
        }
        return false;
    }
};
