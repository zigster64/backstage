const std = @import("std");
const backstage = @import("backstage");
const testing = std.testing;

const Allocator = std.mem.Allocator;
const Context = backstage.Context;
const Request = backstage.Request;
const OrderbookHolderMessage = @import("orderbook_holder.zig").OrderbookHolderMessage;
const TestOrderbookResponse = @import("orderbook_holder.zig").TestOrderbookResponse;
const Envelope = backstage.Envelope;
const OrderbookSubscriptionRequest = @import("orderbook_holder.zig").SubscribeRequest;

pub const StrategyMessage = union(enum) {
    init: struct {},
    subscribe: SubscribeRequest,
    update: UpdateRequest,
};

pub const SubscribeRequest = struct {
    ticker: []const u8,
};

pub const UpdateRequest = struct {
    ticker: []const u8,
    last_timestamp: []const u8,
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

    pub fn receive(self: *Self, message: *const Envelope(StrategyMessage)) !void {
        switch (message.payload) {
            .init => |_| {
                std.debug.print("Strategy initialized\n", .{});
            },
            .subscribe => |m| {
                try self.ctx.send(m.ticker, OrderbookHolderMessage{
                    .subscribe = OrderbookSubscriptionRequest{},
                });
            },
            .update => |m| {
                std.debug.print("Update received: {s}\n", .{m.last_timestamp});
            },
        }
    }
};
