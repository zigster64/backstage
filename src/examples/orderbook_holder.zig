const std = @import("std");
const alphazig = @import("alphazig");
const testing = std.testing;
const ws = @import("websocket");
const concurrency = alphazig.concurrency;

const Coroutine = concurrency.Coroutine;
const Allocator = std.mem.Allocator;
const Context = alphazig.Context;
const Request = alphazig.Request;
// This is an example of a message that can be sent to the CandlesticksActor.
pub const OrderbookHolderMessage = union(enum) {
    init: struct { ticker: []const u8 },
    start: struct {},
    request: Request(TestOrderbookRequest),
};

pub const TestOrderbookRequest = struct {
    id: []const u8,
};


pub const OrderbookHolder = struct {
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
                // while (true) {
                var buffer: [200]u8 = undefined;
                const written = try std.fmt.bufPrint(&buffer, "{{\"method\":\"subscribe\",\"params\":{{\"channel\":\"book\",\"symbol\":[\"{s}\"]}}}}\n", .{"BTC/USD"});

                const mutable_slice = buffer[0..written.len];

                try self.ws_client.write(mutable_slice);
                Coroutine(listenToOrderbook).go(self);

                // try self.ws_client.handshake("/v2", .{
                //     .timeout_ms = 1000,
                // });
                // std.debug.print("Ticker: {s}, Candlestick: {any}, Amount: {d}\n", .{ self.ticker, candlestick, self.candlesticks.items.len });
                // self.ctx.yield();
                // }
            },
            .request => |_| {

            },
        }
    }
    fn listenToOrderbook(self: *Self) !void {
        while (true) {
            const ws_msg = try self.ws_client.read();
            if (ws_msg) |msg| {
                std.debug.print("Message: {s}\n", .{msg.data});
            }
            self.ctx.yield();
        }
    }
};
