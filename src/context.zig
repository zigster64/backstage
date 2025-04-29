const std = @import("std");
const reg = @import("registry.zig");
const act = @import("actor.zig");
const eng = @import("engine.zig");
const xev = @import("xev");

const Allocator = std.mem.Allocator;
const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;
const Engine = eng.Engine;
const SpawnActorOptions = eng.SpawnActorOptions;

pub const Context = struct {
    actor_id: []const u8,
    engine: *Engine,
    actor: *ActorInterface,
    parent_actor: ?*ActorInterface,
    // TODO: Use a better data structure
    child_actors: std.ArrayList(*ActorInterface),

    const Self = @This();
    pub fn init(allocator: Allocator, engine: *Engine, actor_id: []const u8) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .engine = engine,
            .child_actors = std.ArrayList(*ActorInterface).init(allocator),
            .parent_actor = null,
            .actor = undefined,
            .actor_id = actor_id,
        };
        return self;
    }

    pub fn send(self: *const Self, id: []const u8, message: anytype) !void {
        try self.engine.send(self.actor, id, message);
    }
    pub fn request(self: *const Self, id: []const u8, message: anytype, comptime ResultType: type) !ResultType {
        return try self.engine.request(self.actor, id, message, ResultType);
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
                const actor = @as(*ActorType, @ptrCast(@alignCast(ud.?)));
                callback_fn(actor) catch unreachable;
                loop.timer(c, delay_ms, ud, inner);
                return .disarm;
            }
        }.inner;

        self.engine.loop.timer(completion, delay_ms, userdata, callback);
    }

    pub fn getActor(self: *const Self, id: []const u8) ?*ActorInterface {
        return self.engine.registry.getByID(id);
    }
    pub fn spawnActor(self: *Self, comptime ActorType: type, comptime MsgType: type, options: SpawnActorOptions) !*ActorInterface {
        return try self.engine.spawnActor(ActorType, MsgType, options);
    }
    pub fn spawnChildActor(self: *Self, comptime ActorType: type, comptime MsgType: type, options: SpawnActorOptions) !*ActorInterface {
        const actor = try self.engine.spawnActor(ActorType, MsgType, options);
        actor.ctx.parent_actor = self.actor;
        try self.child_actors.append(actor);
        return actor;
    }
    pub fn deinitChildActor(self: *Self, actor: *ActorInterface) void {
        for (self.child_actors.items, 0..) |child, i| {
            if (std.mem.eql(u8, child.ctx.actor_id, actor.ctx.actor_id)) {
                const removed_actor = self.child_actors.orderedRemove(i);
                removed_actor.deinit();
            }
        }
    }
    pub fn deinitChildActorByID(self: *Self, id: []const u8) void {
        for (self.child_actors.items, 0..) |child, i| {
            if (std.mem.eql(u8, child.ctx.actor_id, id)) {
                const removed_actor = self.child_actors.orderedRemove(i);
                removed_actor.deinit();
            }
        }
    }
};
