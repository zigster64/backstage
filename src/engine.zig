const reg = @import("registry.zig");
const act = @import("actor.zig");
const actor_ctx = @import("context.zig");
const std = @import("std");
const xev = @import("xev");
const envlp = @import("envelope.zig");
const type_utils = @import("type_utils.zig");

const Allocator = std.mem.Allocator;
const Registry = reg.Registry;
const ActorInterface = act.ActorInterface;
const Context = actor_ctx.Context;
const MessageType = envlp.MessageType;
const Envelope = envlp.Envelope;
const unsafeAnyOpaqueCast = type_utils.unsafeAnyOpaqueCast;

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

    pub fn spawnActor(self: *Self, comptime ActorType: type, options: ActorOptions) !*ActorType {
        const actor = self.registry.getByID(options.id);
        if (actor) |a| {
            return unsafeAnyOpaqueCast(ActorType, a.impl);
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
        return unsafeAnyOpaqueCast(ActorType, actor_interface.impl);
    }
    pub fn removeAndCleanupActor(self: *Self, id: []const u8) !void {
        const actor = self.registry.fetchRemove(id);
        if (actor) |a| {
            a.cleanupFrameworkResources();
            self.allocator.destroy(a);
        }
    }

    pub fn send(
        self: *Self,
        sender_id: ?[]const u8,
        target_id: []const u8,
        message: anytype,
    ) !void {
        return self.enqueueMessage(
            sender_id,
            target_id,
            .send,
            message,
        );
    }
    pub fn publish(
        self: *Self,
        sender_id: ?[]const u8,
        target_id: []const u8,
        message: anytype,
    ) !void {
        return self.enqueueMessage(
            sender_id,
            target_id,
            .publish,
            message,
        );
    }

    pub fn subscribeToActorTopic(
        self: *Self,
        sender_id: []const u8,
        target_id: []const u8,
        topic: []const u8,
    ) !void {
        return self.enqueueMessage(
            sender_id,
            target_id,
            .subscribe,
            topic,
        );
    }

    pub fn unsubscribeFromActorTopic(
        self: *Self,
        sender_id: []const u8,
        target_id: []const u8,
        topic: []const u8,
    ) !void {
        return self.enqueueMessage(
            sender_id,
            target_id,
            .unsubscribe,
            topic,
        );
    }

    fn enqueueMessage(
        self: *Self,
        sender_id: ?[]const u8,
        target_id: []const u8,
        message_type: MessageType,
        message: anytype,
    ) !void {
        const actor = self.registry.getByID(target_id);
        if (actor) |a| {
            const T = @TypeOf(message);
            switch (@typeInfo(T)) {
                .pointer => |ptr| if (ptr.child != u8) @compileError("Only []const u8 supported"),
                .@"struct" => if (!comptime type_utils.hasMethod(T, "encode")) @compileError("Struct must have encode() method"),
                else => @compileError("Message must be []const u8 or protobuf struct"),
            }

            if (@typeInfo(T) == .@"struct") {
                const encoded = try message.encode(self.allocator);
                defer self.allocator.free(encoded);
                const envelope = Envelope.init(
                    sender_id,
                    message_type,
                    encoded,
                );
                defer envelope.deinit(self.allocator);
                try a.inbox.enqueue(try envelope.toBytes(self.allocator));
            } else {
                const envelope = Envelope.init(
                    sender_id,
                    message_type,
                    message,
                );
                defer envelope.deinit(self.allocator);
                try a.inbox.enqueue(try envelope.toBytes(self.allocator));
            }
        } else {
            std.log.warn("Actor not found: {s}", .{target_id});
        }
    }
};
