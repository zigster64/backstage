const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Inbox = struct {
    fifo: std.fifo.LinearFifo(u8, .Dynamic),
    allocator: Allocator,
    msg_type_size: usize,

    const Self = @This();

    pub fn init(allocator: Allocator, comptime T: type, capacity: usize) !Self {
        const msg_type_size = @sizeOf(T);

        var fifo = std.fifo.LinearFifo(u8, .Dynamic).init(allocator);
        try fifo.ensureTotalCapacity(msg_type_size * capacity);

        return .{
            .fifo = fifo,
            .allocator = allocator,
            .msg_type_size = msg_type_size,
        };
    }

    pub fn deinit(self: *Self) void {
        self.fifo.deinit();
    }

    pub fn send(self: *Self, message: anytype) !void {
        const msg_size = @sizeOf(@TypeOf(message));
        if (msg_size != self.msg_type_size) {
            return error.InvalidMessageSize;
        }

        if (self.fifo.writableLength() < msg_size) {
            return error.BufferFull;
        }

        const bytes = std.mem.asBytes(&message);
        self.fifo.writeAssumeCapacity(bytes);

        return;
    }

    pub fn receive(self: *Self, value: anytype) !bool {
        const value_size = @sizeOf(@TypeOf(value.*));
        if (value_size != self.msg_type_size) {
            return error.InvalidMessageSize;
        }

        if (self.fifo.readableLength() < value_size) {
            return false;
        }

        const value_bytes = std.mem.asBytes(value);

        const bytes_read = self.fifo.read(value_bytes[0..value_size]);
        if (bytes_read != value_size) {
            return error.IncompleteRead;
        }

        return true;
    }

    pub fn tryReceive(self: *Self, value: anytype) bool {
        return self.receive(value) catch false;
    }

    pub fn isEmpty(self: *Self) bool {
        return self.fifo.readableLength() == 0;
    }

    pub fn isFull(self: *Self) bool {
        return self.fifo.writableLength() < self.msg_type_size;
    }

    pub fn messageCount(self: *Self) usize {
        return self.fifo.readableLength() / self.msg_type_size;
    }
};