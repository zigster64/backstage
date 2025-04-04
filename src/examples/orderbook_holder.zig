const std = @import("std");
const backstage = @import("backstage");
const ws = @import("websocket");
const kraken = @import("kraken.zig");
const strtgy = @import("strategy.zig");

const testing = std.testing;
const xev = backstage.xev;
const Allocator = std.mem.Allocator;
const Context = backstage.Context;
const Request = backstage.Request;
const Broker = kraken.Broker;
const parseOrderbookMessage = kraken.parseOrderbookMessage;
const Envelope = backstage.Envelope;
const ActorInterface = backstage.ActorInterface;
const StrategyMessage = strtgy.StrategyMessage;

pub const OrderbookHolderMessage = union(enum) {
    init: struct { ticker: []const u8 },
    start: struct {},
    subscribe: SubscribeRequest,
};

pub const SubscribeRequest = struct {};

pub const OrderbookHolder = struct {
    allocator: Allocator,
    ticker: []const u8 = "",
    timer: xev.Completion,
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
            .timer = xev.Completion{},
            .broker = try Broker.init(allocator),
        };
        return self;
    }

    pub fn deinit(_: *Self) void {}

    pub fn receive(self: *Self, message: *const Envelope(OrderbookHolderMessage)) !void {
        switch (message.payload) {
            .init => |m| {
                self.ticker = m.ticker;
            },
            .start => |_| {
                try self.broker.subscribeToOrderbook(self.ticker);
                try self.ctx.runContinuously(
                    Self,
                    listenToOrderbook,
                    &self.timer,
                    @ptrCast(self),
                    0,
                );
            },
            .subscribe => |_| {
                try self.subscriptions.append(message.sender.?);
            },
        }
    }

    fn listenToOrderbook(self: *Self) !void {
        const ws_msg = try self.broker.readMessage();
        if (ws_msg) |msg| {
            switch (msg) {
                .snapshot => |snapshot| {
                    for (self.subscriptions.items) |actor| {
                        try actor.send(self.ctx.actor, StrategyMessage{ .update = snapshot });
                    }
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
