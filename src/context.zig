const std = @import("std");
const reg = @import("registry.zig");
const act = @import("actor.zig");
const eng = @import("engine.zig");
const con = @import("concurrency/scheduler.zig");

const Allocator = std.mem.Allocator;
const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;
const Engine = eng.Engine;
const SpawnActorOptions = eng.SpawnActorOptions;
const Scheduler = con.Scheduler;

pub const Context = struct {
    engine: *Engine,
    scheduler: Scheduler,
    self: *ActorInterface,
    parent_actor: ?*ActorInterface,
    child_actors: std.ArrayList(*ActorInterface),

    const Self = @This();
    pub fn init(allocator: Allocator, engine: *Engine) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .engine = engine,
            .child_actors = std.ArrayList(*ActorInterface).init(allocator),
            .scheduler = Scheduler.init(null),
            .parent_actor = null,
            .self = undefined,
        };
        return self;
    }

    pub fn send(self: *const Self, id: []const u8, message: anytype) !void {
        const actor = self.engine.Registry.getByID(id);
        if (actor) |a| {
            try a.inbox.send(message);
        }
    }

    pub fn getCoroutineID(self: *const Self) i64 {
        return self.scheduler.get_coroutine_id();
    }
    pub fn getLastCoroutineID(self: *const Self) i64 {
        return self.scheduler.get_last_coroutine_id();
    }
    pub fn suspendRoutine(self: *const Self) void {
        self.scheduler.suspend_routine();
    }
    pub fn resumeRoutine(self: *const Self, id: i64) void {
        self.scheduler.resume_routine(id);
    }
    pub fn sleepRoutine(self: *const Self, ns: i64) void {
        self.scheduler.sleep(ns);
    }
    pub fn yield(self: *const Self) void {
        self.scheduler.yield();
    }

    pub fn getActor(self: *const Self, id: []const u8) ?*ActorInterface {
        return self.engine.Registry.getByID(id);
    }

    pub fn spawnChildActor(self: *Self, comptime ActorType: type, comptime MsgType: type, options: SpawnActorOptions) !*ActorInterface {
        const actor = try self.engine.spawnActor(ActorType, MsgType, options);
        actor.ctx.parent_actor = self.self;
        try self.child_actors.append(actor);
        return actor;
    }
};
