const reg = @import("registry.zig");
const act = @import("actor.zig");
const envlp = @import("envelope.zig");
const actor_ctx = @import("context.zig");
const std = @import("std");
const chan = @import("concurrency/channel.zig");
const Allocator = std.mem.Allocator;
const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;
const Context = actor_ctx.Context;
const Channel = chan.Channel;
const Request = @import("request.zig").Request;
const Envelope = envlp.Envelope;
pub const SpawnActorOptions = struct {
    id: []const u8,
    capacity: usize = 1024,
};

pub const Engine = struct {
    Registry: Registry,
    allocator: Allocator,

    const Self = @This();
    pub fn init(allocator: Allocator) Self {
        return .{
            .Registry = Registry.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.Registry.deinit();
    }

    pub fn spawnActor(self: *Self, comptime ActorType: type, comptime MsgType: type, options: SpawnActorOptions) !*ActorInterface {
        const ctx = try Context.init(self.allocator, self);
        const actor_interface = try ActorInterface.create(self.allocator, ctx, ActorType, Envelope(MsgType), options.capacity);
        errdefer actor_interface.deinit();

        try self.Registry.add(options.id, Envelope(MsgType), actor_interface);
        return actor_interface;
    }

    pub fn send(self: *Self, sender: *?ActorInterface, id: []const u8, message: anytype) !void {
        const actor = self.Registry.getByID(id);
        if (actor) |a| {
            try a.inbox.send(Envelope(@TypeOf(message)).init(sender, message));
        }
    }
    pub fn broadcast(self: *Self, sender: *?ActorInterface, message: anytype) !void {
        const actor = self.Registry.getByMessageType(message);
        if (actor) |a| {
            try a.inbox.send(Envelope(@TypeOf(message)).init(sender, message));
        }
    }

    pub fn request(self: *Engine, id: []const u8, original_message: anytype, comptime ResultType: type) !ResultType {
        const actor = self.Registry.getByID(id);

        var message = original_message;
        var result: ResultType = undefined;

        var ch = try Channel.init(ResultType, 1);
        try ch.retain();
        switch (message) {
            .request => |*req| {
                req.result = ch;
            },
            else => {
                return error.InvalidMessageType;
            },
        }
        if (actor) |a| {
            try a.inbox.send(message);
        }
        try ch.receive(&result);
        ch.deinit();
        return result;
    }
};
