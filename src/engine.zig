const reg = @import("registry.zig");
const act = @import("actor.zig");
const actor_ctx = @import("context.zig");
const std = @import("std");
const xev = @import("xev");

const Allocator = std.mem.Allocator;
const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;
const Context = actor_ctx.Context;

pub const ActorOptions = struct {
    id: []const u8,
    capacity: usize = 1024,
};

pub const Engine = struct {
    registry: Registry,
    allocator: Allocator,
    loop: xev.Loop,
    const Self = @This();
    pub fn init(allocator: Allocator) !Self {
        return .{
            .registry = Registry.init(allocator),
            .allocator = allocator,
            .loop = try xev.Loop.init(.{}),
        };
    }

    pub fn run(self: *Self) !void {
        try self.loop.run(.until_done);
    }

    pub fn deinit(self: *Self) void {
        self.loop.deinit();
        var it = self.registry.actorsIDMap.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinitFnPtr(entry.value_ptr.*.impl) catch |err| {
                std.log.err("Failed to deinit actor: {s}", .{@errorName(err)});
            };
        }
        self.registry.deinit();
    }

    pub fn spawnActor(self: *Self, comptime ActorType: type, options: ActorOptions) !*ActorInterface {
        const actor = self.registry.getByID(options.id);
        if (actor) |a| {
            return a;
        }
        const actor_interface = try ActorInterface.create(
            self.allocator,
            self,
            ActorType,
            options,
        );
        errdefer actor_interface.deinitFnPtr(actor_interface.impl) catch |err| {
            std.log.err("Failed to deinit actor: {s}", .{@errorName(err)});
        };

        try self.registry.add(options.id, actor_interface);
        return actor_interface;
    }
    pub fn deinitActor(self: *Self, id: []const u8) !void {
        const actor = self.registry.fetchRemove(id);
        if (actor) |a| {
            try a.deinit();
            self.allocator.destroy(a);
        }
    }

    pub fn send(self: *Self, sender: ?*ActorInterface, id: []const u8, message: []const u8) !void {
        const actor = self.registry.getByID(id);
        if (actor) |a| {
            try a.send(sender, message);
        } else {
            return error.ActorNotFound;
        }
    }
    // pub fn broadcast(self: *Self, sender: ?*const ActorInterface, message: anytype) !void {
    //     const actor = self.registry.getByMessageType(message);
    //     if (actor) |a| {
    //         try a.send(sender, message);
    //     }
    // }

    pub fn request(self: *Engine, sender: ?*const ActorInterface, id: []const u8, original_message: anytype, comptime ResultType: type) !ResultType {
        // Needs to be reimplemented
        _ = sender;
        _ = id;
        _ = original_message;
        _ = self;
    }
};
