const std = @import("std");
const backstage = @import("backstage");
const testing = std.testing;
const ws = @import("websocket");
const concurrency = backstage.concurrency;
const kraken = @import("kraken.zig");
const Coroutine = concurrency.Coroutine;
const Allocator = std.mem.Allocator;
const Context = backstage.Context;
const Request = backstage.Request;
const serialize_request = kraken.serialize_request;
const SubscriptionRequest = kraken.SubscriptionRequest;
const deserialize_request = kraken.deserialize_request;
const parseOrderbookMessage = kraken.parseOrderbookMessage;
const Envelope = backstage.Envelope;

pub const OrderbookHolderMessage = union(enum) {
    init: struct { ticker: []const u8 },
    start: struct {},
    request: Request(TestOrderbookRequest),
};

pub const TestOrderbookRequest = struct {
    id: []const u8,
};
pub const TestOrderbookResponse = struct {
    last_timestamp: []const u8,
};

pub const OrderbookHolder = struct {
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    ticker: []const u8 = "",
    ws_client: ws.Client,
    ctx: *Context,
    last_timestamp: []const u8 = "",
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
                var buffer: [128]u8 = undefined;
                const req = try serialize_request(SubscriptionRequest{
                    .method = "subscribe",
                    .params = .{
                        .channel = "book",
                        .symbol = &[_][]const u8{self.ticker},
                    },
                }, &buffer);
                try self.ws_client.write(req);
                Coroutine(listenToOrderbook).go(self);
            },
            .request => |req| {
                try req.result.?.send(TestOrderbookResponse{ .last_timestamp = self.last_timestamp });
            },
        }
    }

    fn listenToOrderbook(self: *Self) !void {
        while (true) {
            const ws_msg = try self.ws_client.read();
            if (ws_msg) |msg| {
                const orderbook_message = try parseOrderbookMessage(msg.data, self.arena.allocator());
                if (orderbook_message) |message| {
                    switch (message) {
                        .snapshot => |snapshot| {
                            std.debug.print("Orderbook message: {}\n", .{snapshot});
                        },
                        .update => |update| {
                            std.debug.print("Update message: {}\n", .{update});
                            self.last_timestamp = update.data[0].timestamp.?;
                        },
                    }
                }
            }
            self.ctx.yield();
        }
    }
};
