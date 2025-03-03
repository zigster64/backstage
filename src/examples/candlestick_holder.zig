const std = @import("std");
const alphazig = @import("alphazig");
const testing = std.testing;
const concurrency = alphazig.concurrency;

const Allocator = std.mem.Allocator;
const Context = alphazig.Context;

// This is an example of a message that can be sent to the CandlesticksActor.
pub const CandlestickHolderMessage = union(enum) {
    init: struct { ticker: []const u8 },
};

pub const Candlestick = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};

pub const CandlestickHolder = struct {
    candlesticks: std.ArrayList(Candlestick),

    pub fn init(ctx: *Context, allocator: Allocator) !*@This() {
        _ = ctx;
        const self = try allocator.create(@This());
        self.* = .{
            .candlesticks = std.ArrayList(Candlestick).init(allocator),
        };
        return self;
    }

    pub fn receive(_: *@This(), message: *const CandlestickHolderMessage) !void {
        switch (message.*) {
            .init => |m| {
                std.debug.print("Starting holder {s}\n", .{m.ticker});
            },
        }
    }
};
