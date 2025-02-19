const std = @import("std");

const RingBuffer = std.RingBuffer;
const Allocator = std.mem.Allocator;

pub const Inbox = struct {
    ring_buffer: RingBuffer,
    
    pub fn init(allocator: Allocator, capacity: usize) !Inbox {
        return .{
            .ring_buffer = try RingBuffer.init(allocator, capacity),
        };
    }

    pub fn deinit(self: *Inbox) void {
        self.ring_buffer.deinit();
    }
};
