const std = @import("std");
const alphazig = @import("alphazig");
const testing = std.testing;
const concurrency = alphazig.concurrency;

const Allocator = std.mem.Allocator;
const Context = alphazig.Context;

// This is an example of a message that can be sent to the CandlesticksActor.
pub const CandlestickHolderMessage = union(enum) {
    init: struct { ticker: []const u8 },
    subscribe: struct {},
};

pub const Candlestick = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};

pub const CandlestickHolder = struct {
    ticker: []const u8 = "",
    candlesticks: std.ArrayList(Candlestick),
    ctx: *Context,
    const Self = @This();
    pub fn init(ctx: *Context, allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .ctx = ctx,
            .candlesticks = std.ArrayList(Candlestick).init(allocator),
        };
        return self;
    }

    pub fn receive(self: *Self, message: *const CandlestickHolderMessage) !void {
        switch (message.*) {
            .init => |m| {
                std.debug.print("Starting holder {s}\n", .{m.ticker});
                self.ticker = m.ticker;
            },
            .subscribe => |_| {
                while (true) {
                    const candlestick = Candlestick{
                        .open = 1,
                        .high = 2,
                        .low = 3,
                        .close = 4,
                    };
                    self.candlesticks.append(candlestick) catch unreachable;
                    // std.debug.print("Ticker: {s}, Candlestick: {any}, Amount: {d}\n", .{ self.ticker, candlestick, self.candlesticks.items.len });
                    self.ctx.yield();
                }
            },
        }
    }
};
