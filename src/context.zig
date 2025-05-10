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
    child_actors: std.StringHashMap(*ActorInterface),

    const Self = @This();
    pub fn init(allocator: Allocator, engine: *Engine, actor_id: []const u8) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .engine = engine,
            .child_actors = std.StringHashMap(*ActorInterface).init(allocator),
            .parent_actor = null,
            .actor = undefined,
            .actor_id = actor_id,
        };
        return self;
    }

    pub fn deinit(self: *Self) !void {
        defer self.child_actors.deinit();
        var it = self.child_actors.valueIterator();
        while (it.next()) |actor| {
            try actor.*.ctx.deinit();
        }
        if (self.parent_actor) |parent| {
            const could_detach = parent.*.ctx.detachChildActor(self.actor);
            if (!could_detach) {
                return error.FailedToDetachChildActor;
            }
        }
        try self.actor.deinitCore();
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
        try self.child_actors.put(options.id, actor);
        std.debug.print("Amount of child actors: {}\n", .{self.child_actors.count()});
    }
    pub fn detachChildActor(self: *Self, actor: *ActorInterface) bool {
        return self.child_actors.remove(actor.ctx.actor_id);
    }
    pub fn detachChildActorByID(self: *Self, id: []const u8) bool {
        return self.child_actors.remove(id);
    }
};
