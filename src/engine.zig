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

    pub fn spawnActor(self: *Engine, comptime ActorType: type, comptime MsgType: type, id: []const u8, allocator: std.mem.Allocator) !void {
        const actorInstance = try ActorType.init(allocator);
        const wrapper = act.makeReceiveWrapper(ActorType, MsgType);
        const actorInterface = ActorInterface.init(actorInstance, wrapper);

        const messageTypeNames = type_utils.getTypeNames(MsgType);
        std.debug.print("typeNames: {s}\n", .{messageTypeNames});

        try self.Registry.add(id, &messageTypeNames, actorInterface);
    }

    pub fn send(self: *Engine, comptime MsgType: type, id: []const u8, message: *const MsgType) void {
        const actor = self.Registry.getByID(id);
        if (actor) |a| {
            a.receive(message);
        }
    }
    pub fn broadcast(self: *Engine, comptime MsgType: type, message: *const MsgType) void {
        // TODO Move this to generic place
        const active_tag = std.meta.activeTag(message.*);
        const TagType = @TypeOf(active_tag);
        
        inline for (std.meta.fields(TagType)) |field| {
            if (active_tag == @field(TagType, field.name)) {
                const PayloadType = std.meta.TagPayloadByName(MsgType, field.name);
                const actor = self.Registry.getByMessageType(@typeName(PayloadType));
                if (actor) |a| {
                    a.receive(message);
                }
                break;
            }
        }
    }

    // pub fn request(self: *Engine, id: []const u8, message: MessageInterface) void {
    //     const actor = self.Registry.get(id);
    //     if (actor) |a| {
    //         a.receive(message);
    //     }
    // }
};
