const std = @import("std");

pub fn serialize_request(req: SubscriptionRequest, buffer: []u8) ![]u8 {
    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    try std.json.stringify(req, .{}, writer);
    return stream.getWritten();
}

pub fn deserialize_request(allocator: std.mem.Allocator, json_str: []const u8) !WsMessage {
    const parsed = try std.json.parseFromSlice(
        WsMessage,
        allocator,
        json_str,
        .{},
    );
    defer parsed.deinit();

    return parsed.value;
}

pub fn parseOrderbookMessage(json_str: []const u8, allocator: std.mem.Allocator) !WsMessage {
    var raw_json = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer raw_json.deinit();

    const raw_value = raw_json.value;
    const channel = if (raw_value.object.get("channel")) |ch| ch.string else "";
    const type_str = if (raw_value.object.get("type")) |t| t.string else "";
    const method = if (raw_value.object.get("method")) |t| t.string else "";

    const message_type: MessageType = std.meta.stringToEnum(MessageType, channel) orelse
        std.meta.stringToEnum(MessageType, type_str) orelse
        std.meta.stringToEnum(MessageType, method) orelse
        return error.InvalidMessageType;

    return switch (message_type) {
        .heartbeat => .{ .heartbeat = .{ .channel = "heartbeat" } },
        .status => {
            const status_json = try std.json.parseFromValue(StatusMessage, allocator, raw_value, .{});
            // defer status_json.deinit();
            return .{ .status = status_json.value };
        },
        .pong => {
            const pong_json = try std.json.parseFromValue(PongMessage, allocator, raw_value, .{});
            // defer pong_json.deinit();
            return .{ .pong = pong_json.value };
        },
        .snapshot => {
            const snapshot_json = try std.json.parseFromValue(SnapshotMessage, allocator, raw_value, .{});
            // defer snapshot_json.deinit();
            return .{ .snapshot = snapshot_json.value };
        },
        .update => {
            const update_json = try std.json.parseFromValue(UpdateMessage, allocator, raw_value, .{});
            // defer update_json.deinit();
            return .{ .update = update_json.value };
        },
        .subscribe => {
            const subscribe_json = try std.json.parseFromValue(SubscribeMessage, allocator, raw_value, .{});
            // defer subscribe_json.deinit();
            return .{ .subscribe = subscribe_json.value };
        },
    };
}

pub const SubscriptionRequest = struct {
    method: []const u8,
    params: struct {
        channel: []const u8,
        symbol: []const []const u8,
    },
};

const MessageType = enum { heartbeat, status, pong, snapshot, update, subscribe };

pub const WsMessage = union(MessageType) {
    heartbeat: HeartbeatMessage,
    status: StatusMessage,
    pong: PongMessage,
    snapshot: SnapshotMessage,
    update: UpdateMessage,
    subscribe: SubscribeMessage,
};

pub const SubscribeMessage = struct {
    method: []const u8,
    result: struct {
        channel: []const u8,
        depth: u32,
        snapshot: bool,
        symbol: []const u8,
    },
    success: bool,
    time_in: []const u8,
    time_out: []const u8,
};

pub const HeartbeatMessage = struct {
    channel: []const u8,
};

const StatusData = struct {
    system: []const u8,
    api_version: []const u8,
    connection_id: u64,
    version: []const u8,
};

const StatusMessage = struct {
    channel: []const u8,
    type: []const u8,
    data: []const StatusData,
};

const PongMessage = struct {
    method: []const u8,
    req_id: u64,
    time_in: []const u8,
    time_out: []const u8,
};

pub const Order = struct {
    price: f64,
    qty: f64,
};

pub const SnapshotData = struct {
    symbol: []const u8,
    bids: []const Order,
    asks: []const Order,
    checksum: u64,
};

pub const SnapshotMessage = struct {
    channel: []const u8,
    type: []const u8,
    data: []const SnapshotData,
};

pub const UpdateData = struct {
    symbol: []const u8,
    bids: []const Order,
    asks: []const Order,
    checksum: u64,
    timestamp: []const u8,
};

pub const UpdateMessage = struct {
    channel: []const u8,
    type: []const u8,
    data: []const UpdateData,
};
