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

    pub fn init(allocator: Allocator, engine: *Engine) !*@This() {
        const self = try allocator.create(@This());
        self.* = .{
            .engine = engine,
            .child_actors = std.ArrayList(*ActorInterface).init(allocator),
            .scheduler = Scheduler.init(null),
            .parent_actor = null,
            .self = undefined,
        };
        return self;
    }

    pub fn getActor(self: *@This(), id: []const u8) ?*ActorInterface {
        return self.engine.Registry.getByID(id);
    }

    pub fn spawnChildActor(self: *@This(), comptime ActorType: type, comptime MsgType: type, options: SpawnActorOptions) !*ActorInterface {
        const actor = try self.engine.spawnActor(ActorType, MsgType, options);
        actor.ctx.parent_actor = self.self;
        try self.child_actors.append(actor);
        return actor;
    }
};
