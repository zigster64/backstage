const reg = @import("registry.zig");
const act = @import("actor.zig");
const msg = @import("message.zig");
const actor_ctx = @import("context.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;
const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;
const Context = actor_ctx.Context;
pub const SpawnActorOptions = struct {
    id: []const u8,
    capacity: usize = 1024,
};

pub const Engine = struct {
    Registry: Registry,
    allocator: Allocator,

    const Self = @This();
    pub fn init(allocator: Allocator) Self {
        return .{
            .Registry = Registry.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.Registry.deinit();
    }

    pub fn spawnActor(self: *Self, comptime ActorType: type, comptime MsgType: type, options: SpawnActorOptions) !*ActorInterface {
        const ctx = try Context.init(self.allocator, self);
        const actor_interface = try ActorInterface.create(self.allocator, ctx, ActorType, MsgType, options.capacity);
        errdefer actor_interface.deinit(self.allocator);

        try self.Registry.add(options.id, MsgType, actor_interface);
        return actor_interface;
    }

    pub fn send(self: *Self, id: []const u8, message: anytype) !void {
        const actor = self.Registry.getByID(id);
        if (actor) |a| {
            try a.inbox.send(message);
        }
    }
    pub fn broadcast(self: *Self, message: anytype) !void {
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
