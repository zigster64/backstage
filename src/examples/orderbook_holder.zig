const std = @import("std");
const backstage = @import("backstage");
const testing = std.testing;
const ws = @import("websocket");
// const concurrency = backstage.concurrency;
const kraken = @import("kraken.zig");
// const Coroutine = concurrency.Coroutine;
const Allocator = std.mem.Allocator;
const Context = backstage.Context;
const Request = backstage.Request;
const Broker = @import("kraken.zig").Broker;
const parseOrderbookMessage = kraken.parseOrderbookMessage;
const Envelope = backstage.Envelope;
const ActorInterface = backstage.ActorInterface;
const StrategyMessage = @import("strategy.zig").StrategyMessage;
const Completion = backstage.Completion;
pub const OrderbookHolderMessage = union(enum) {
    init: struct { ticker: []const u8 },
    start: struct {},
    subscribe: SubscribeRequest,
};

pub const SubscribeRequest = struct {};
pub const TestOrderbookResponse = struct {
    last_timestamp: []const u8,
};

pub const OrderbookHolder = struct {
    allocator: Allocator,
    ticker: []const u8 = "",
    timer: Completion,
    ctx: *Context,
    broker: *Broker,
    subscriptions: std.ArrayList(*ActorInterface),
    const Self = @This();
    pub fn init(ctx: *Context, allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .ctx = ctx,
            .subscriptions = std.ArrayList(*ActorInterface).init(allocator),
            .timer = Completion{},
            .broker = try Broker.init(allocator),
        };
        return self;
    }

    pub fn deinit(_: *Self) void {}

    pub fn receive(self: *Self, message: *const Envelope(OrderbookHolderMessage)) !void {
        switch (message.payload) {
            .init => |m| {
                std.debug.print("Orderbook holder init {s}\n", .{m.ticker});
                self.ticker = m.ticker;
            },
            .start => |_| {
                try self.broker.subscribeToOrderbook(self.ticker);
                try self.addTimer();
            },
            .subscribe => |_| {
                std.debug.print("Subscribing to orderbook {s}\n", .{self.ticker});
                try self.subscriptions.append(message.sender.?);
            },
        }
    }

    pub fn addTimer(self: *Self) !void {
        self.ctx.addTimer(@ptrCast(self), &self.timer, 0, Self, listenToOrderbook);
    }

    fn listenToOrderbook(self: *Self) !void {
        const ws_msg = try self.broker.readMessage();
        if (ws_msg) |msg| {
            switch (msg) {
                .snapshot => |snapshot| {
                    std.debug.print("Orderbook message: {}\n", .{snapshot});
                },
                .update => |update| {
                    for (self.subscriptions.items) |actor| {
                        try actor.send(self.ctx.actor, StrategyMessage{ .update = update });
                    }
                },
            }
        }
    }
};
