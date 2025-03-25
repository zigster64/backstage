const std = @import("std");
const backstage = @import("backstage");
const orderbook_hldr = @import("orderbook_holder.zig");
const kraken = @import("kraken.zig");

const Allocator = std.mem.Allocator;
const Context = backstage.Context;
const Envelope = backstage.Envelope;
const OrderbookHolderMessage = orderbook_hldr.OrderbookHolderMessage;
const UpdateMessage = kraken.UpdateMessage;

pub const StrategyMessage = union(enum) {
    init: struct {},
    subscribe: SubscribeRequest,
    update: UpdateMessage,
};

pub const SubscribeRequest = struct {
    ticker: []const u8,
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
            .init => |_| {},
            .subscribe => |m| {
                try self.ctx.send(m.ticker, OrderbookHolderMessage{ .subscribe = .{} });
            },
            .update => |m| {
                std.debug.print("Update received: {}\n", .{m});
            },
        }
    }
};
