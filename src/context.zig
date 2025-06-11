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
    actor_id: []const u8,
    engine: *Engine,
    actor: *ActorInterface,
    parent_actor: ?*ActorInterface,
    child_actors: std.StringHashMap(*ActorInterface),
    topic_subscriptions: std.StringHashMap(std.StringHashMap(void)),

    const Self = @This();
    pub fn init(allocator: Allocator, engine: *Engine, actor: *ActorInterface, actor_id: []const u8) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .engine = engine,
            .child_actors = std.StringHashMap(*ActorInterface).init(allocator),
            .parent_actor = null,
            .actor = actor,
            .actor_id = actor_id,
            .topic_subscriptions = std.StringHashMap(std.StringHashMap(void)).init(allocator),
        };
        return self;
    }

    pub fn shutdown(self: *Self) !void {
        if (self.child_actors.count() != 0) {
            var it = self.child_actors.valueIterator();
            while (it.next()) |actor| {
                try actor.*.deinitFnPtr(actor.*.impl);
            }
            self.child_actors.deinit();
        }
        // TODO Deinit subscribed_actor_ids

        if (self.parent_actor) |parent| {
            _ = parent.*.ctx.detachChildActor(self.actor);
        }

        try self.engine.removeAndCleanupActor(self.actor_id);
    }

    pub fn send(self: *const Self, target_id: []const u8, message: []const u8) !void {
        try self.engine.send(self.actor_id, target_id, .send, message);
    }

    pub fn publish(self: *const Self, message: []const u8) !void {
        try self.publishToTopic("default", message);
    }

    pub fn publishToTopic(self: *const Self, topic: []const u8, message: []const u8) !void {
        if (self.topic_subscriptions.get(topic)) |subscribers| {
            var it = subscribers.keyIterator();
            while (it.next()) |id| {
                try self.engine.send(self.actor_id, id.*, .publish, message);
            }
        }
    }
    pub fn subscribeToActor(self: *const Self, target_id: []const u8) !void {
        try self.subscribeToActorTopic(target_id, "default");
    }

    pub fn subscribeToActorTopic(self: *const Self, target_id: []const u8, topic: []const u8) !void {
        try self.engine.subscribeToActorTopic(self.actor_id, target_id, topic);
    }

    pub fn unsubscribeFromActor(self: *const Self, target_id: []const u8) !void {
        try self.unsubscribeFromActorTopic(target_id, "default");
    }

    pub fn unsubscribeFromActorTopic(self: *const Self, target_id: []const u8, topic: []const u8) !void {
        try self.engine.unsubscribeFromActorTopic(self.actor_id, target_id, topic);
    }

    pub fn getLoop(self: *const Self) *xev.Loop {
        return &self.engine.loop;
    }

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
        const actor = try self.engine.spawnActor(ActorType, options);
        actor.ctx.parent_actor = self.actor;
        // TODO Find a way to make this work again
        // try self.child_actors.put(options.id, actor);
        return actor;
    }
    pub fn detachChildActor(self: *Self, actor: *ActorInterface) bool {
        return self.child_actors.remove(actor.ctx.actor_id);
    }
    pub fn detachChildActorByID(self: *Self, id: []const u8) bool {
        return self.child_actors.remove(id);
    }
};
