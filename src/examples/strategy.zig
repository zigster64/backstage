const std = @import("std");
const alphazig = @import("alphazig");
const testing = std.testing;
const concurrency = alphazig.concurrency;

const Allocator = std.mem.Allocator;
const Context = alphazig.Context;
const Request = alphazig.Request;
const CandlestickHolderMessage = @import("candlestick_holder.zig").CandlestickHolderMessage;
const TestCandlestickRequest = @import("candlestick_holder.zig").TestCandlestickRequest;
const TestCandlestickResponse = @import("candlestick_holder.zig").TestCandlestickResponse;
// This is an example of a message that can be sent to the CandlesticksActor.
pub const StrategyMessage = union(enum) {
    init: struct {},
    request: struct {},
};

pub const Strategy = struct {
    ctx: *Context,
    coroutine_id: i64,
    const Self = @This();

    pub fn init(ctx: *Context, allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .ctx = ctx,
            .coroutine_id = 0,
        };
        return self;
    }

    pub fn receive(self: *Self, message: *const StrategyMessage) !void {
        switch (message.*) {
            .init => |_| {
                std.debug.print("Strategy initialized\n", .{});
            },
            .request => |_| {
                std.debug.print("Request received\n", .{});
                var res = try self.ctx.request("EUR_HKD", CandlestickHolderMessage{
                    .request = Request(TestCandlestickRequest){
                        .payload = TestCandlestickRequest{ .id = "EUR_HKD" },
                        .result = undefined,
                    },
                }, TestCandlestickResponse);
                defer res.deinit();
                var resp: TestCandlestickResponse = undefined;
                _ = try res.receive(&resp);
                std.debug.print("Response received: {any}\n", .{resp});
            },
        }
    }
};
