const std = @import("std");
const reg = @import("registry.zig");
const act = @import("actor.zig");
const eng = @import("engine.zig");
const xev = @import("xev");
const type_utils = @import("type_utils.zig");

const Allocator = std.mem.Allocator;
const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;
const Engine = eng.Engine;
const ActorOptions = eng.ActorOptions;
const unsafeAnyOpaqueCast = type_utils.unsafeAnyOpaqueCast;

pub const Context = struct {
    allocator: Allocator,
    actor_id: []const u8,
    engine: *Engine,
    actor: *ActorInterface,
    parent_actor: ?*ActorInterface,
    child_actors: std.StringHashMap(*ActorInterface),
    topic_subscriptions: std.StringHashMap(std.StringHashMap(void)),
    subscribed_to_actors: std.StringHashMap(std.StringHashMap(void)),

    const Self = @This();
    pub fn init(allocator: Allocator, engine: *Engine, actor: *ActorInterface, actor_id: []const u8) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .engine = engine,
            .child_actors = std.StringHashMap(*ActorInterface).init(allocator),
            .parent_actor = null,
            .actor = actor,
            .actor_id = actor_id,
            .topic_subscriptions = std.StringHashMap(std.StringHashMap(void)).init(allocator),
            .subscribed_to_actors = std.StringHashMap(std.StringHashMap(void)).init(allocator),
        };
        return self;
    }

    pub fn shutdown(self: *Self) !void {
        if (self.subscribed_to_actors.count() != 0) {
            var it = self.subscribed_to_actors.iterator();
            while (it.next()) |entry| {
                var it2 = entry.value_ptr.keyIterator();
                while (it2.next()) |topic| {
                    self.engine.unsubscribeFromActorTopic(self.actor_id, entry.key_ptr.*, topic.*) catch |err| {
                        std.log.warn("Failed to unsubscribe from {s} topic {s}: {}", .{ entry.key_ptr.*, topic.*, err });
                    };
                }

                var topic_it = entry.value_ptr.keyIterator();
                while (topic_it.next()) |topic| {
                    self.allocator.free(topic.*);
                }
                entry.value_ptr.deinit();

                self.allocator.free(entry.key_ptr.*);
            }
            self.subscribed_to_actors.deinit();
        }

        if (self.child_actors.count() != 0) {
            var it = self.child_actors.valueIterator();
            while (it.next()) |actor| {
                try actor.*.deinitFnPtr(actor.*.impl);
            }
            self.child_actors.deinit();
        }

        if (self.parent_actor) |parent| {
            _ = parent.*.ctx.detachChildActor(self.actor);
        }

        try self.engine.removeAndCleanupActor(self.actor_id);
    }

    pub fn send(self: *const Self, target_id: []const u8, message: anytype) !void {
        try self.engine.send(self.actor_id, target_id, .send, message);
    }

    pub fn publish(self: *const Self, message: anytype) !void {
        try self.publishToTopic("default", message);
    }

    pub fn publishToTopic(self: *const Self, topic: []const u8, message: anytype) !void {
        if (self.topic_subscriptions.get(topic)) |subscribers| {
            var it = subscribers.keyIterator();
            while (it.next()) |id| {
                try self.engine.send(self.actor_id, id.*, .publish, message);
            }
        }
    }
    pub fn subscribeToActor(self: *Self, target_id: []const u8) !void {
        try self.subscribeToActorTopic(target_id, "default");
    }

    pub fn subscribeToActorTopic(self: *Self, target_id: []const u8, topic: []const u8) !void {
        const owned_target_id = try self.allocator.dupe(u8, target_id);
        const owned_topic = try self.allocator.dupe(u8, topic);
        try self.engine.subscribeToActorTopic(self.actor_id, owned_target_id, owned_topic);
        const result = try self.subscribed_to_actors.getOrPut(owned_target_id);
        if (!result.found_existing) {
            result.value_ptr.* = std.StringHashMap(void).init(self.allocator);
        }
        try result.value_ptr.put(owned_topic, {});
    }

    pub fn unsubscribeFromActor(self: *Self, target_id: []const u8) !void {
        try self.unsubscribeFromActorTopic(target_id, "default");
    }

    pub fn unsubscribeFromActorTopic(self: *Self, target_id: []const u8, topic: []const u8) !void {
        try self.engine.unsubscribeFromActorTopic(self.actor_id, target_id, topic);
        var actor_map = self.subscribed_to_actors.get(target_id).?;
        if (actor_map.fetchRemove(topic)) |owned_topic| {
            self.allocator.free(owned_topic.key);
        }
        if (actor_map.count() == 0) {
            if (self.subscribed_to_actors.fetchRemove(target_id)) |owned_target_id| {
                self.allocator.free(owned_target_id.key);
            }
            actor_map.deinit();
        }
    }

    pub fn getLoop(self: *const Self) *xev.Loop {
        return &self.engine.loop;
    }

    // TODO Wrap this in a struct so that it can be properly disposed
    pub fn runContinuously(
        self: *Self,
        comptime ActorType: type,
        comptime callback_fn: anytype,
        completion: *xev.Completion,
        userdata: ?*anyopaque,
        comptime delay_ms: u64,
    ) !void {
        const callback = struct {
            fn inner(
                ud: ?*anyopaque,
                loop: *xev.Loop,
                c: *xev.Completion,
                _: xev.Result,
            ) xev.CallbackAction {
                const actor = unsafeAnyOpaqueCast(ActorType, ud);
                callback_fn(actor) catch |err| {
                    std.log.err("Failed to run callback: {s}", .{@errorName(err)});
                    return .disarm;
                };
                loop.timer(c, delay_ms, ud, inner);
                return .disarm;
            }
        }.inner;

        self.engine.loop.timer(completion, delay_ms, userdata, callback);
    }

    pub fn getActor(self: *const Self, id: []const u8) ?*ActorInterface {
        return self.engine.registry.getByID(id);
    }
    pub fn spawnActor(self: *Self, comptime ActorType: type, options: ActorOptions) !*ActorType {
        return try self.engine.spawnActor(ActorType, options);
    }
    pub fn spawnChildActor(self: *Self, comptime ActorType: type, options: ActorOptions) !*ActorType {
        const actor_impl = try self.engine.spawnActor(ActorType, options);
        actor_impl.ctx.parent_actor = self.actor;
        // TODO Find a way to make this work again
        try self.child_actors.put(options.id, actor_impl.ctx.actor);
        return actor_impl;
    }
    pub fn detachChildActor(self: *Self, actor: *ActorInterface) bool {
        return self.child_actors.remove(actor.ctx.actor_id);
    }
    pub fn detachChildActorByID(self: *Self, id: []const u8) bool {
        return self.child_actors.remove(id);
    }
};
