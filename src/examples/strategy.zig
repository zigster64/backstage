const std = @import("std");
const alphazig = @import("alphazig");
const testing = std.testing;
const concurrency = alphazig.concurrency;

const Allocator = std.mem.Allocator;
const Context = alphazig.Context;
const Request = alphazig.Request;
const OrderbookHolderMessage = @import("orderbook_holder.zig").OrderbookHolderMessage;
const TestOrderbookRequest = @import("orderbook_holder.zig").TestOrderbookRequest;
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

    pub fn receive(_: *Self, message: *const StrategyMessage) !void {
        switch (message.*) {
            .init => |_| {
                std.debug.print("Strategy initialized\n", .{});
            },
            .request => |_| {
                // const res = try self.ctx.request("EUR_HKD", OrderbookHolderMessage{
                //     .request = Request(TestOrderbookRequest){
                //         .payload = TestOrderbookRequest{ .id = "EUR_HKD" },
                //     },
                // }, TestOrderbookResponse);
                // std.debug.print("Response received: {any}\n", .{res});
            },
        }
    }
};
