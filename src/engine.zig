const reg = @import("registry.zig");
const act = @import("actor.zig");
const msg = @import("message.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;
const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;

const SpawnActorOptions = struct {
    id: []const u8,
    capacity: usize = 1024,
};

pub const Engine = struct {
    Registry: Registry,
    allocator: Allocator,

    pub fn init(allocator: Allocator) Engine {
        return .{
            .Registry = Registry.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Engine) void {
        self.Registry.deinit();
    }

    pub fn spawnActor(self: *Engine, comptime ActorType: type, comptime MsgType: type, options: SpawnActorOptions) !*ActorInterface {
        const actor_interface = try ActorInterface.init(self, ActorType, MsgType, options.capacity);
        errdefer actor_interface.deinit();

        try self.Registry.add(options.id, MsgType, actor_interface);
        return actor_interface;
    }

    pub fn send(self: *Engine, id: []const u8, message: anytype) !void {
        const actor = self.Registry.getByID(id);
        if (actor) |a| {
            try a.inbox.send(message);
        }
    }
    pub fn broadcast(self: *Engine, message: anytype) !void {
        const actor = self.Registry.getByMessageType(message);
        if (actor) |a| {
            try a.inbox.send(message);
        }
    }

    // pub fn request(self: *Engine, id: []const u8, message: MessageInterface) void {
    //     const actor = self.Registry.get(id);
    //     if (actor) |a| {
    //         a.receive(message);
    //     }
    // }
};
