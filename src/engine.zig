const reg = @import("registry.zig");
const act = @import("actor.zig");
const msg = @import("message.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;
const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;
const MessageInterface = msg.MessageInterface;

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

    pub fn spawn(self: *Engine, id: []const u8, a: ActorInterface) !void {
        try self.Registry.add(id, a);
    }

    pub fn send(self: *Engine, id: []const u8) void {
        const actor = self.Registry.get(id);
        if (actor) |a| {
            a.receive();
        }
    }

    pub fn request(self: *Engine, id: []const u8, message: MessageInterface) void {
        const actor = self.Registry.get(id);
        if (actor) |a| {
            a.receive(message);
        }
    }
};
