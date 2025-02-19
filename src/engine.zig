const reg = @import("registry.zig");
const act = @import("actor.zig");
const msg = @import("message.zig");
const type_utils = @import("type_utils.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;
const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;
// const MessageInterface = msg.MessageInterface;

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

    pub fn spawnActor(self: *Engine, allocator: std.mem.Allocator, comptime ActorType: type, comptime MsgType: type, id: []const u8) !void {
        const actor_instance = try ActorType.init(allocator);
        const receiveFn = act.makeReceiveFn(ActorType, MsgType);
        const actor_interface = try ActorInterface.init(allocator, actor_instance, receiveFn);

        const message_type_names = type_utils.getTypeNames(MsgType);
        try self.Registry.add(id, &message_type_names, actor_interface);
    }

    pub fn send(self: *Engine, comptime MsgType: type, id: []const u8, message: *const MsgType) void {
        const actor = self.Registry.getByID(id);
        if (actor) |a| {
            a.receive(message);
        }
    }
    pub fn broadcast(self: *Engine, comptime MsgType: type, message: *const MsgType) void {
        const active_type_name = type_utils.getActiveTypeName(MsgType, message);
        const actor = self.Registry.getByMessageType(active_type_name);
        if (actor) |a| {
            a.receive(message);
        }
    }

    // pub fn request(self: *Engine, id: []const u8, message: MessageInterface) void {
    //     const actor = self.Registry.get(id);
    //     if (actor) |a| {
    //         a.receive(message);
    //     }
    // }
};
