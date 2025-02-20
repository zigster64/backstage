const reg = @import("registry.zig");
const act = @import("actor.zig");
const msg = @import("message.zig");
const type_utils = @import("type_utils.zig");
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

    pub fn spawnActor(self: *Engine, comptime ActorType: type, comptime MsgType: type, options: SpawnActorOptions) !void {
        const actor_instance = try ActorType.init(self.allocator);
        const receiveFn = act.makeReceiveFn(ActorType, MsgType);
        const actor_interface = try ActorInterface.init(self.allocator, actor_instance, options.capacity, receiveFn);

        const message_type_names = type_utils.getTypeNames(MsgType);
        try self.Registry.add(options.id, &message_type_names, actor_interface);
    }

    pub fn send(self: *Engine, id: []const u8, message: anytype) !void {
        const actor = self.Registry.getByID(id);
        if (actor) |a| {
            try a.inbox.send(message);
            // a.receive();
        }
    }
    pub fn broadcast(self: *Engine, message: anytype) !void {
        const active_type_name = type_utils.getActiveTypeName(message);
        const actor = self.Registry.getByMessageType(active_type_name);
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
