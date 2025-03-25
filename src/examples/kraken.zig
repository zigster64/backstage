const ws = @import("websocket");
const backstage = @import("backstage");

pub const Broker = struct {
    allocator: std.mem.Allocator,
    ws_client: ws.Client,
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);

        var client = try ws.Client.init(allocator, .{ .host = "ws.kraken.com", .port = 443, .tls = true });
        try client.handshake("/v2", .{
            .timeout_ms = 5000,
            .headers = "Host: ws.kraken.com\r\nOrigin: https://www.kraken.com",
        });
        errdefer client.deinit();

        self.* = .{ .allocator = allocator, .ws_client = client };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
        self.ws_client.deinit();
    }

    pub fn subscribeToOrderbook(self: *Self, ticker: []const u8) !void {
        std.debug.print("Subscribing to orderbook for {s}\n", .{ticker});
        var buffer: [128]u8 = undefined;
        const req = try jsonMarshalFixedBuffer(WsSubsribeRequest{
            .method = "subscribe",
            .params = .{
                .channel = "book",
                .symbol = &[_][]const u8{ticker},
            },
        }, &buffer);
        try self.ws_client.write(req);
    }

    pub fn readMessage(self: *Self) !?WsResponseMessage {
        const ws_msg = try self.ws_client.read();
        if (ws_msg) |msg| {
            defer self.ws_client.done(msg);
            var arena_state = std.heap.ArenaAllocator.init(self.allocator);
            // Currently not really handling memory freeing, not that important for an example
            // defer arena_state.deinit();
            return try parseOrderbookMessage(msg.data, arena_state.allocator());
        }
        return null;
    }
};

const std = @import("std");

pub const WsSubsribeRequest = struct {
    method: []const u8,
    params: struct {
        channel: []const u8,
        symbol: []const []const u8,
    },
};

const WsResponseMessageType = enum { snapshot, update };

pub const WsResponseMessage = union(WsResponseMessageType) {
    snapshot: UpdateMessage,
    update: UpdateMessage,
};

pub const PriceLevel = struct {
    price: f64,
    qty: f64,
};

pub const UpdateData = struct {
    symbol: []const u8,
    bids: []const PriceLevel,
    asks: []const PriceLevel,
    checksum: u64,
    timestamp: ?[]const u8 = null,
};

pub const UpdateMessage = struct {
    channel: []const u8,
    type: []const u8,
    data: []const UpdateData,
};

pub fn parseOrderbookMessage(json_str: []const u8, allocator: std.mem.Allocator) !?WsResponseMessage {
    var raw_json = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer raw_json.deinit();

    const raw_value = raw_json.value;
    const channel_str = if (raw_value.object.get("channel")) |c| c.string else "";
    if (!std.mem.eql(u8, channel_str, "book")) {
        return null;
    }
    const type_str = if (raw_value.object.get("type")) |t| t.string else "";

    const message_type: WsResponseMessageType = std.meta.stringToEnum(WsResponseMessageType, type_str) orelse
        return null;

    return switch (message_type) {
        .snapshot => {
            const snapshot_json = try std.json.parseFromValue(UpdateMessage, allocator, raw_value, .{});
            return .{ .snapshot = snapshot_json.value };
        },
        .update => {
            const update_json = try std.json.parseFromValue(UpdateMessage, allocator, raw_value, .{});
            return .{ .update = update_json.value };
        },
    };
}

pub fn jsonMarshalFixedBuffer(req: anytype, buffer: []u8) ![]u8 {
    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    try std.json.stringify(req, .{}, writer);
    return stream.getWritten();
}

pub fn jsonUnmarshal(comptime T: type, allocator: std.mem.Allocator, buffer: []u8) !T {
    const parsed = try std.json.parseFromSlice(
        T,
        allocator,
        buffer,
        .{},
    );
    defer parsed.deinit();

    return parsed.value;
}
