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
pub const CandlestickHolderMessage = union(enum) {
    init: struct { ticker: []const u8 },
    start: struct {},
    request: Request(TestCandlestickRequest),
};

pub const TestCandlestickRequest = struct {
    id: []const u8,
};

pub const TestCandlestickResponse = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    aaaa: f64,
};

pub const Candlestick = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};

pub const CandlestickHolder = struct {
    ticker: []const u8 = "",
    candlesticks: std.ArrayList(Candlestick),
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
            .candlesticks = std.ArrayList(Candlestick).init(allocator),
            .ws_client = client,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.candlesticks.deinit();
        self.ws_client.deinit();
    }

    pub fn receive(self: *Self, message: *const CandlestickHolderMessage) !void {
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
            .request => |m| {
                while (true) {
                    std.debug.print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAa\n", .{});
                    self.ctx.yield();
                }
                std.debug.print("m.result: {any}\n", .{m.result});
                try m.result.?.send(TestCandlestickResponse{
                    .open = 1,
                    .high = 2,
                    .low = 3,
                    .close = 4,
                    .aaaa = 5,
                });
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
