const std = @import("std");

const LinearFifo = std.fifo.LinearFifo;
const RingBuffer = std.RingBuffer;
const Allocator = std.mem.Allocator;

pub const Inbox = struct {
    fifo: LinearFifo(u8, .Dynamic),

    pub fn init(allocator: Allocator, capacity: usize) !*Inbox {
        const inbox = try allocator.create(Inbox);
        inbox.fifo = LinearFifo(u8, .Dynamic).init(allocator);
        try inbox.fifo.ensureTotalCapacity(capacity);
        return inbox;
    }

    pub fn deinit(self: *Inbox) void {
        self.fifo.deinit();
    }

    pub fn send(self: *Inbox, message: anytype) !void {
        const bytes = std.mem.asBytes(&message);
        try self.fifo.write(bytes);
    }

    pub fn receive(self: *Inbox, value: anytype) bool {
        const value_size = @sizeOf(@TypeOf(value.*));
        if (self.fifo.readableLength() < value_size) {
            return false;
        }

        const bytes = self.fifo.readableSlice(0)[0..value_size];
        @memcpy(std.mem.asBytes(value), bytes);
        _ = self.fifo.discard(value_size);
        return true;
    }
};
