const reg = @import("registry.zig");
const act = @import("actor.zig");
const actor_ctx = @import("context.zig");
const std = @import("std");
const xev = @import("xev");
const envlp = @import("envelope.zig");
const type_utils = @import("type_utils.zig");

const Allocator = std.mem.Allocator;
const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;
const Context = actor_ctx.Context;
const MessageType = envlp.MessageType;
const unsafeAnyOpaqueCast = type_utils.unsafeAnyOpaqueCast;

pub const ActorOptions = struct {
    id: []const u8,
    capacity: usize = 1024,
};

pub const Engine = struct {
    registry: Registry,
    allocator: Allocator,
    loop: xev.Loop,
    const Self = @This();
    pub fn init(allocator: Allocator) !Self {
        return .{
            .registry = Registry.init(allocator),
            .allocator = allocator,
            .loop = try xev.Loop.init(.{}),
        };
    }

    pub fn run(self: *Self) !void {
        try self.loop.run(.until_done);
    }

    pub fn deinit(self: *Self) void {
        self.loop.deinit();
        var it = self.registry.actorsIDMap.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinitFnPtr(entry.value_ptr.*.impl) catch |err| {
                std.log.err("Failed to deinit actor: {s}", .{@errorName(err)});
            };
        }
        self.registry.deinit();
    }

    pub fn spawnActor(self: *Self, comptime ActorType: type, options: ActorOptions) !*ActorType {
        const actor = self.registry.getByID(options.id);
        if (actor) |a| {
            return unsafeAnyOpaqueCast(ActorType, a.impl);
        }
        const actor_interface = try ActorInterface.create(
            self.allocator,
            self,
            ActorType,
            options,
        );
        errdefer actor_interface.deinitFnPtr(actor_interface.impl) catch |err| {
            std.log.err("Failed to deinit actor: {s}", .{@errorName(err)});
        };

        try self.registry.add(options.id, actor_interface);
        return unsafeAnyOpaqueCast(ActorType, actor_interface.impl);
    }
    pub fn removeAndCleanupActor(self: *Self, id: []const u8) !void {
        const actor = self.registry.fetchRemove(id);
        if (actor) |a| {
            a.cleanupFrameworkResources();
            self.allocator.destroy(a);
        }
    }

    pub fn send(
        self: *Self,
        sender_id: ?[]const u8,
        target_id: []const u8,
        message_type: MessageType,
        message: []const u8,
    ) !void {
        const actor = self.registry.getByID(target_id);
        if (actor) |a| {
            try a.send(
                sender_id,
                message_type,
                message,
            );
        } else {
            std.log.warn("Actor not found: {s}", .{target_id});
        }
    }

    pub fn subscribeToActorTopic(
        self: *Self,
        sender_id: []const u8,
        target_id: []const u8,
        topic: []const u8,
    ) !void {
        return self.send(
            sender_id,
            target_id,
            .subscribe,
            topic,
        );
    }

    pub fn unsubscribeFromActorTopic(
        self: *Self,
        sender_id: []const u8,
        target_id: []const u8,
        topic: []const u8,
    ) !void {
        return self.send(
            sender_id,
            target_id,
            .unsubscribe,
            topic,
        );
    }

    pub fn request(self: *Engine, sender: ?*const ActorInterface, id: []const u8, original_message: anytype, comptime ResultType: type) !ResultType {
        // Needs to be reimplemented
        _ = sender;
        _ = id;
        _ = original_message;
        _ = self;
    }
};
