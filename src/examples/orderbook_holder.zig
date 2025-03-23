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
const serialize_request = kraken.serialize_request;
const SubscriptionRequest = kraken.SubscriptionRequest;
const deserialize_request = kraken.deserialize_request;
const parseOrderbookMessage = kraken.parseOrderbookMessage;
const Envelope = backstage.Envelope;
const ActorInterface = backstage.ActorInterface;
const StrategyMessage = @import("strategy.zig").StrategyMessage;
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
    arena: std.heap.ArenaAllocator,
    ticker: []const u8 = "",
    ws_client: ws.Client,
    ctx: *Context,

    subscriptions: std.ArrayList(*ActorInterface),
    const Self = @This();
    pub fn init(ctx: *Context, allocator: Allocator) !*Self {
        const self = try allocator.create(Self);

        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        var client = try ws.Client.init(allocator, .{ .host = "ws.kraken.com", .port = 443, .tls = true });
        try client.handshake("/v2", .{
            .timeout_ms = 5000,
            .headers = "Host: ws.kraken.com\r\nOrigin: https://www.kraken.com",
        });
        errdefer client.deinit();

        self.* = .{
            .allocator = allocator,
            .arena = arena,
            .ctx = ctx,
            .ws_client = client,
            .subscriptions = std.ArrayList(*ActorInterface).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
        self.ws_client.deinit();
    }

    pub fn receive(self: *Self, message: *const Envelope(OrderbookHolderMessage)) !void {
        switch (message.payload) {
            .init => |m| {
                std.debug.print("Starting holder {s}\n", .{m.ticker});
                self.ticker = m.ticker;
            },
            .start => |_| {
                std.debug.print("STARTING HOLDER {s}\n", .{self.ticker});
                var buffer: [128]u8 = undefined;
                const req = try serialize_request(SubscriptionRequest{
                    .method = "subscribe",
                    .params = .{
                        .channel = "book",
                        .symbol = &[_][]const u8{self.ticker},
                    },
                }, &buffer);
                try self.ws_client.write(req);
                // Coroutine(listenToOrderbook).go(self);
                self.ctx.addTimer(0, Self, listenToOrderbook);
            },
            .subscribe => |_| {
                try self.subscriptions.append(message.sender.?);
            },
        }
    }

    fn listenToOrderbook(self: *Self) !void {
        const ws_msg = try self.ws_client.read();
        std.debug.print("LISTENING TO ORDERBOOK\n", .{});
        if (ws_msg) |msg| {
            const orderbook_message = try parseOrderbookMessage(msg.data, self.arena.allocator());
            if (orderbook_message) |message| {
                switch (message) {
                    .snapshot => |snapshot| {
                        std.debug.print("Orderbook message: {}\n", .{snapshot});
                    },
                    .update => |update| {
                        std.debug.print("Update message: {}\n", .{update});
                        for (self.subscriptions.items) |actor| {
                            try actor.send(self.ctx.actor, StrategyMessage{ .update = .{
                                .ticker = self.ticker,
                                .last_timestamp = "123",
                            } });
                        }
                    },
                }
            }
        }
    }
};
