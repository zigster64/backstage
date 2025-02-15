const std = @import("std");
const act = @import("actor.zig");

const ActorInterface = act.ActorInterface;
const StringHashMap = std.StringHashMap;

pub const Registry = struct {
    actors: StringHashMap(ActorInterface),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{
            .actors = StringHashMap(ActorInterface).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Registry) void {
        self.actors.deinit();
    }

    pub fn get(self: *Registry, id: []const u8) ?ActorInterface {
        return self.actors.get(id);
    }

    pub fn add(self: *Registry, id: []const u8, actor: ActorInterface) !void {
        try self.actors.put(id, actor);
    }
};
