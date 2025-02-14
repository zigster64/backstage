const std = @import("std");
const act = @import("actor.zig");

const ActorInterface = act.ActorInterface;
const AutoHashMap = std.AutoHashMap;

pub const Registry = struct {
    actors: AutoHashMap([]const u8, ActorInterface),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{
            .actors = AutoHashMap([]const u8, ActorInterface).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Registry) void {
        self.actors.deinit();
    }

    pub fn get(self: *Registry, id: []const u8) ?*ActorInterface {
        return self.actors.get(id);
    }

    pub fn add(self: *Registry, id: []const u8, actor: *anyopaque) !void {
        const interface = ActorInterface.init(actor);
        try self.actors.put(id, interface);
    }
};
