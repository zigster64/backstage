const std = @import("std");
const inbox = @import("inbox.zig");
const eng = @import("engine.zig");
const ctxt = @import("context.zig");
const envlp = @import("envelope.zig");
const xev = @import("xev");
const type_utils = @import("type_utils.zig");

const Allocator = std.mem.Allocator;
const Inbox = inbox.Inbox;
const Engine = eng.Engine;
const Context = ctxt.Context;
const Envelope = envlp.Envelope;
const unsafeAnyOpaqueCast = type_utils.unsafeAnyOpaqueCast;

pub const ActorInterface = struct {
    impl: *anyopaque,
    inbox: *Inbox,
    ctx: *Context,
    completion: xev.Completion = undefined,

    deinitFnPtr: *const fn (ptr: *anyopaque) anyerror!void,

    const Self = @This();

    pub fn create(
        allocator: Allocator,
        ctx: *Context,
        comptime ActorType: type,
        actor_impl: *anyopaque,
        capacity: usize,
    ) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .impl = actor_impl,
            .inbox = try Inbox.init(allocator, capacity),
            .ctx = ctx,
            .deinitFnPtr = makeTypeErasedDeinitFn(ActorType),
        };
        ctx.actor = self;
        try self.listenForMessages(ActorType);

        return self;
    }
    fn listenForMessages(self: *Self, comptime ActorType: type) !void {
        const listenForMessagesFn = struct {
            fn inner(
                ud: ?*anyopaque,
                loop: *xev.Loop,
                c: *xev.Completion,
                _: xev.Result,
            ) xev.CallbackAction {
                const inner_self: *Self = unsafeAnyOpaqueCast(Self, ud);
                const maybe_bytes = inner_self.inbox.dequeue() catch {
                    inner_self.deinit(true) catch |err| {
                        std.log.err("Failed to deinit actor: {s}", .{@errorName(err)});
                        return .disarm;
                    };
                    return .disarm;
                };
                if (maybe_bytes) |bytes| {
                    const actor_impl = @as(*ActorType, @ptrCast(@alignCast(inner_self.impl)));
                    actor_impl.receive(bytes) catch {
                        inner_self.deinit(true) catch |err| {
                            std.log.err("Failed to deinit actor: {s}", .{@errorName(err)});
                            return .disarm;
                        };
                        return .disarm;
                    };
                    return .rearm;
                }

                loop.timer(c, 0, ud, inner);
                return .disarm;
            }
        }.inner;
        self.ctx.engine.loop.timer(&self.completion, 0, @ptrCast(self), listenForMessagesFn);
    }

    pub fn deinit(self: *Self, deinit_impl: bool) anyerror!void {
        try self.deinitChildrenAndDetachFromParent(deinit_impl);
        self.inbox.deinit();
        if (deinit_impl) {
            try self.deinitFnPtr(self.impl);
        }
    }

    pub fn send(self: *Self, sender: ?*ActorInterface, msg: []const u8) !void {
        try self.inbox.enqueue(Envelope.init(
            if (sender) |s| s.ctx.actor_id else null,
            msg,
        ));
    }
    fn deinitChildrenAndDetachFromParent(self: *Self, deinit_impl: bool) !void {
        var it = self.ctx.child_actors.valueIterator();
        while (it.next()) |actor| {
            try actor.*.deinit(deinit_impl);
        }
        self.ctx.child_actors.deinit();

        if (self.ctx.parent_actor) |parent| {
            const could_detach = parent.*.ctx.detachChildActor(self.ctx.actor);
            if (!could_detach) {
                return error.FailedToDetachChildActor;
            }
        }
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
