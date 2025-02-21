const std = @import("std");

pub const StartIntervalMessage = struct {
    interval_ms: u64,
};

// This is an example of a message that can be sent to the CandlesticksActor.
pub const CandlesticksMessage = union(enum) {
    start_interval: StartIntervalMessage,
    candlestick: Candlestick,
};

pub const Candlestick = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};

// This is an example of an unspecific union being able to be sent to the CandlesticksActor.
pub const OtherUnionMessage = union(enum) {
    candlestick: Candlestick,
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
            .start_interval => |start_interval| {
                std.debug.print("Received StartIntervalMessage:\n  interval_ms: {}\n", .{start_interval.interval_ms});
            },
            .candlestick => |candlestick| {
                std.debug.print("Received Candlestick:\n  open: {}\n  high: {}\n  low: {}\n  close: {}\n", .{ candlestick.open, candlestick.high, candlestick.low, candlestick.close });
            },
        }
    }
};
