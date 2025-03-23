const actr = @import("actor.zig");

const ActorInterface = actr.ActorInterface;
pub fn Envelope(comptime PayloadType: type) type {
    return struct {
        sender: ?*ActorInterface,
        payload: PayloadType,
        const Self = @This();
        pub fn init(sender: ?*ActorInterface, payload: PayloadType) Self {
            return .{
                .sender = sender,
                .payload = payload,
            };
        }
    };
}
