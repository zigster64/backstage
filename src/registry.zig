const std = @import("std");
const act = @import("actor.zig");
const type_utils = @import("type_utils.zig");

const ActorInterface = act.ActorInterface;
const StringHashMap = std.StringHashMap;

pub const Registry = struct {
    actorsIDMap: StringHashMap(*ActorInterface),

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{
            .actorsIDMap = StringHashMap(*ActorInterface).init(allocator),
        };
    }

    pub fn deinit(self: *Registry) void {
        self.actorsIDMap.deinit();
    }

    pub fn getByID(self: *Registry, id: []const u8) ?*ActorInterface {
        return self.actorsIDMap.get(id);
    }

    pub fn add(self: *Registry, id: []const u8, actor: *ActorInterface) !void {
        try self.actorsIDMap.put(id, actor);
    }
};
