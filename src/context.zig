const std = @import("std");
const reg = @import("registry.zig");
const act = @import("actor.zig");
const eng = @import("engine.zig");

const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;
const Engine = eng.Engine;
const SpawnActorOptions = eng.SpawnActorOptions;

pub const Context = struct {
    engine: *Engine,
    child_actors: std.ArrayList(*ActorInterface),

    pub fn init(arena: *std.heap.ArenaAllocator, engine: *Engine) !*@This() {

        const allocator = arena.allocator();
        const self = try allocator.create(@This());
        self.* = .{
            .engine = engine,
            .child_actors = std.ArrayList(*ActorInterface).init(allocator),
        };
        return self;
    }

    pub fn getActor(self: *@This(), id: []const u8) ?*ActorInterface {
        return self.engine.Registry.getByID(id);
    }

    pub fn spawnChildActor(self: *@This(), comptime ActorType: type, comptime MsgType: type, options: SpawnActorOptions) !void {
        const actor = try self.engine.spawnActor(ActorType, MsgType, options);
        _ = actor;
        // try self.child_actors.append(actor);
    }
};
