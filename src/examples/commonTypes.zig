const std = @import("std");

// This is an example of a message that can be sent to the CandlesticksActor.
pub const CandlesticksMessage = union(enum) {
    candlestick: Candlestick,
    test_msg: TestMessage,
};

const Candlestick = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};

const TestMessage = struct {
    example: []const u8,
};

// This is an example of an unspecific union being able to be sent to the CandlesticksActor.
pub const WrongMessage = union(enum) {
    candlestick: Candlestick,
    test_msg: WrongTestMessage,
};

const WrongTestMessage = struct {
    example: []const u8,
};

pub const CandlesticksActor = struct {
    candlesticks: std.ArrayList(Candlestick),

    pub fn init(allocator: std.mem.Allocator) !*CandlesticksActor {
        const self = try allocator.create(CandlesticksActor);
        self.* = .{
            .candlesticks = std.ArrayList(Candlestick).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *CandlesticksActor, allocator: std.mem.Allocator) void {
        self.candlesticks.deinit();
        allocator.destroy(self);
    }

    pub fn receive(_: *CandlesticksActor, message: *const CandlesticksMessage) void {
        switch (message.*) {
            .candlestick => |candlestick| {
                std.debug.print("Received Candlestick:\n  open: {}\n  high: {}\n  low: {}\n  close: {}\n", .{ candlestick.open, candlestick.high, candlestick.low, candlestick.close });
            },
            .test_msg => |test_msg| {
                std.debug.print("Received Test Message:\n  example: {s}\n", .{test_msg.example});
            },
        }
    }
};
