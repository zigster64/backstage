const std = @import("std");
const inbox = @import("inbox.zig");
const eng = @import("engine.zig");
const ctxt = @import("context.zig");
const envlp = @import("envelope.zig");
const xev = @import("xev");

const Allocator = std.mem.Allocator;
const Inbox = inbox.Inbox;
const Engine = eng.Engine;
const Context = ctxt.Context;
const Envelope = envlp.Envelope;

pub const ActorInterface = struct {
    ptr: *anyopaque,
    inbox: Inbox,
    ctx: *Context,
    completion: xev.Completion = undefined,

    deinitFnPtr: *const fn (ptr: *anyopaque) anyerror!void,

    const Self = @This();

    pub fn create(
        allocator: Allocator,
        ctx: *Context,
        comptime ActorType: type,
        comptime MsgType: type,
        capacity: usize,
    ) !*Self {
        const actor_instance = try ActorType.init(ctx, allocator);

        const self = try allocator.create(Self);
        self.* = .{
            .ptr = actor_instance,
            .inbox = try Inbox.init(allocator, MsgType, capacity),
            .ctx = ctx,
            .deinitFnPtr = makeTypeErasedDeinitFn(ActorType),
        };
        ctx.actor = self;
        try self.listenForMessages(ActorType, MsgType);

        return self;
    }
    fn listenForMessages(self: *Self, comptime ActorType: type, comptime MsgType: type) !void {
        const listenForMessagesFn = struct {
            fn inner(
                ud: ?*anyopaque,
                loop: *xev.Loop,
                c: *xev.Completion,
                _: xev.Result,
            ) xev.CallbackAction {
                const s: *Self = @as(*Self, @ptrCast(@alignCast(ud.?)));
                var msg: MsgType = undefined;
                const received = s.inbox.receive(&msg) catch unreachable;
                if (received) {
                    const actor_impl = @as(*ActorType, @ptrCast(@alignCast(s.ptr)));
                    actor_impl.receive(&msg) catch unreachable;
                    return .rearm;
                }

                loop.timer(c, 0, ud, inner);
                return .disarm;
            }
        }.inner;
        self.ctx.engine.loop.timer(&self.completion, 0, @ptrCast(self), listenForMessagesFn);
    }

    pub fn deinit(self: *Self) anyerror!void {
        try self.deinitCore();
        try self.deinitFnPtr(self.ptr);
    }

    pub fn deinitCore(self: *Self) anyerror!void {
        self.inbox.deinit();
    }

    pub fn send(self: *Self, sender: ?*ActorInterface, msg: anytype) !void {
        try self.inbox.send(Envelope(@TypeOf(msg)).init(sender, msg));
    }
};

fn makeTypeErasedDeinitFn(comptime ActorType: type) fn (*anyopaque) anyerror!void {
    return struct {
        fn wrapper(ptr: *anyopaque) anyerror!void {
            const self = @as(*ActorType, @ptrCast(@alignCast(ptr)));
            if (comptime hasDeinitMethod(ActorType)) {
                const DeinitFnType = @TypeOf(ActorType.deinit);
                const deinit_fn_info = @typeInfo(DeinitFnType).@"fn";
                const ActualReturnType = deinit_fn_info.return_type.?;

                if (@typeInfo(ActualReturnType) == .error_union) {
                    try ActorType.deinit(self);
                } else {
                    ActorType.deinit(self);
                }
            }
            try self.*.ctx.deinit();
            return;
        }
    }.wrapper;
}
fn hasDeinitMethod(comptime T: type) bool {
    const typeInfo = @typeInfo(T);
    if (typeInfo != .@"struct") return false;

    inline for (typeInfo.@"struct".decls) |decl| {
        if (!std.mem.eql(u8, decl.name, "deinit")) continue;

        const field = @field(T, decl.name);
        const FieldType = @TypeOf(field);
        const fieldInfo = @typeInfo(FieldType);

        if (fieldInfo != .@"fn") continue;

        const FnInfo = fieldInfo.@"fn";
        if (FnInfo.params.len != 1) continue;

        const ParamType = FnInfo.params[0].type.?;
        if (ParamType != *T) continue;

        return true;
    }

    return false;
}
