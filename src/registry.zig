const std = @import("std");
const act = @import("actor.zig");
const type_utils = @import("type_utils.zig");

const ActorInterface = act.ActorInterface;
const StringHashMap = std.StringHashMap;

pub const Registry = struct {
    actorsIDMap: StringHashMap(*ActorInterface),
    actorsMessageTypeMap: StringHashMap(*ActorInterface),

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{
            .actorsIDMap = StringHashMap(*ActorInterface).init(allocator),
            .actorsMessageTypeMap = StringHashMap(*ActorInterface).init(allocator),
        };
    }

    pub fn deinit(self: *Registry) void {
        var it = self.actorsIDMap.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(true) catch |err| {
                std.log.err("Failed to deinit actor: {s}", .{@errorName(err)});
            };
        }
        self.actorsIDMap.deinit();
        self.actorsMessageTypeMap.deinit();
    }

    pub fn getByID(self: *Registry, id: []const u8) ?*ActorInterface {
        return self.actorsIDMap.get(id);
    }

    // TODO This obviously needs to return a slice of actors
    pub fn getByMessageType(self: *Registry, message: anytype) ?ActorInterface {
        const active_type_name = type_utils.getActiveTypeName(message);
        return self.actorsMessageTypeMap.get(active_type_name);
    }

    pub fn add(self: *Registry, id: []const u8, comptime MsgType: type, actor: *ActorInterface) !void {
        const message_type_names = type_utils.getTypeNames(MsgType);

        try self.actorsIDMap.put(id, actor);
        for (message_type_names) |messageType| {
            try self.actorsMessageTypeMap.put(messageType, actor);
        }
    }
};
