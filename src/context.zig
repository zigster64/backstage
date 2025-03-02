const std = @import("std");
const reg = @import("registry.zig");
const act = @import("actor.zig");
const eng = @import("engine.zig");
const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;
const Engine = eng.Engine;
pub const Context = struct {
    engine: *Engine,

    pub fn init(arena: *std.heap.ArenaAllocator, engine: *Engine) !*@This() {
        const allocator = arena.allocator();
        const self = try allocator.create(@This());
        self.* = .{ .engine = engine };
        return self;
    }

    pub fn getActor(self: *@This(), id: []const u8) ?*ActorInterface {
        return self.engine.Registry.getByID(id);
    }
};
