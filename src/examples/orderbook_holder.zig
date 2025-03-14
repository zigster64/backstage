const std = @import("std");
const alphazig = @import("alphazig");
const testing = std.testing;
const ws = @import("websocket");
const concurrency = alphazig.concurrency;
const kraken = @import("kraken.zig");
const Coroutine = concurrency.Coroutine;
const Allocator = std.mem.Allocator;
const Context = alphazig.Context;
const Request = alphazig.Request;
const serialize_request = kraken.serialize_request;
const SubscriptionRequest = kraken.SubscriptionRequest;
const OrderbookMessage = kraken.SnapshotMessage;
const deserialize_request = kraken.deserialize_request;
const parseOrderbookMessage = kraken.parseOrderbookMessage;
// This is an example of a message that can be sent to the OrderbookHolderActor.
pub const OrderbookHolderMessage = union(enum) {
    init: struct { ticker: []const u8 },
    start: struct {},
    request: Request(TestOrderbookRequest),
};

pub const TestOrderbookRequest = struct {
    id: []const u8,
};

pub const OrderbookHolder = struct {
    allocator: Allocator,
    ticker: []const u8 = "",
    ws_client: ws.Client,
    ctx: *Context,
    const Self = @This();
    pub fn init(ctx: *Context, allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        var client = try ws.Client.init(allocator, .{ .host = "ws.kraken.com", .port = 443, .tls = true });
        try client.handshake("/v2", .{
            .timeout_ms = 5000,
            .headers = "Host: ws.kraken.com\r\nOrigin: https://www.kraken.com",
        });
        self.* = .{
            .allocator = allocator,
            .ctx = ctx,
            .ws_client = client,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.ws_client.deinit();
    }

    pub fn receive(self: *Self, message: *const OrderbookHolderMessage) !void {
        switch (message.*) {
            .init => |m| {
                std.debug.print("Starting holder {s}\n", .{m.ticker});
                self.ticker = m.ticker;
            },
            .start => |_| {
                var buffer: [128]u8 = undefined;
                const req = try serialize_request(SubscriptionRequest{
                    .method = "subscribe",
                    .params = .{
                        .channel = "book",
                        .symbol = &[_][]const u8{"BTC/USD"},
                    },
                }, &buffer);
                try self.ws_client.write(req);
                Coroutine(listenToOrderbook).go(self);
            },
            .request => |_| {},
        }
    }
    // TODO Use Arena allocator
    fn listenToOrderbook(self: *Self) !void {
        while (true) {
            const ws_msg = try self.ws_client.read();
            if (ws_msg) |msg| {
                const orderbook_message = try parseOrderbookMessage(msg.data, self.allocator);
                switch (orderbook_message) {
                    .heartbeat => |heartbeat| {
                        std.debug.print("Heartbeat message: {}\n", .{heartbeat});
                    },
                    .status => |status| {
                        std.debug.print("Status message: {}\n", .{status});
                    },
                    .pong => |pong| {
                        std.debug.print("Pong message: {}\n", .{pong});
                    },
                    .snapshot => |snapshot| {
                        std.debug.print("Orderbook message: {}\n", .{snapshot});
                    },
                    .update => |update| {
                        std.debug.print("Update message: {}\n", .{update});
                    },
                    .subscribe => |subscribe| {
                        std.debug.print("Subscribe message: {}\n", .{subscribe});
                    },
                }
            }
            self.ctx.yield();
        }
    }
};
