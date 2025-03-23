const std = @import("std");
// const concurrency = @import("concurrency/root.zig");

// const Channel = concurrency.Channel;
const Allocator = std.mem.Allocator;

pub const Inbox = struct {
    fifo: std.fifo.LinearFifo(u8, .Dynamic),
    allocator: Allocator,
    msg_type_size: usize,
    mutex: std.Thread.Mutex,

    const Self = @This();

    pub fn init(allocator: Allocator, comptime T: type, capacity: usize) !Self {
        // Calculate the buffer size needed
        const msg_type_size = @sizeOf(T);

        // Initialize the FIFO with the required capacity
        var fifo = std.fifo.LinearFifo(u8, .Dynamic).init(allocator);
        try fifo.ensureTotalCapacity(msg_type_size * capacity);

        return .{
            .fifo = fifo,
            .allocator = allocator,
            .msg_type_size = msg_type_size,
            .mutex = .{},
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

        self.mutex.lock();
        defer self.mutex.unlock();
        std.debug.print("Message type: {s}\n", .{@typeName(@TypeOf(message))});
        // Check if there's enough space in the buffer
        if (self.fifo.writableLength() < msg_size) {
            return error.BufferFull;
        }

        // Write the message to the buffer
        const bytes = std.mem.asBytes(&message);
        self.fifo.writeAssumeCapacity(bytes);

        return;
    }

    pub fn receive(self: *Self, value: anytype) !bool {
        const value_size = @sizeOf(@TypeOf(value.*));
        if (value_size != self.msg_type_size) {
            return error.InvalidMessageSize;
        }

        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if there's a message to read
        if (self.fifo.readableLength() < value_size) {
            // No message available - this is not an error condition
            return false;
        }

        // Read the message from the buffer
        const value_bytes = std.mem.asBytes(value);

        const bytes_read = self.fifo.read(value_bytes[0..value_size]);
        if (bytes_read != value_size) {
            return error.IncompleteRead;
        }

        return true;
    }

    pub fn tryReceive(self: *Self, value: anytype) bool {
        // We now use our updated receive function that returns a boolean
        return self.receive(value) catch false;
    }

    pub fn isEmpty(self: *Self) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.fifo.readableLength() == 0;
    }

    pub fn isFull(self: *Self) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.fifo.writableLength() < self.msg_type_size;
    }

    pub fn messageCount(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.fifo.readableLength() / self.msg_type_size;
    }
};
