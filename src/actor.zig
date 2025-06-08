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
const ActorOptions = eng.ActorOptions;
const unsafeAnyOpaqueCast = type_utils.unsafeAnyOpaqueCast;

pub const ActorInterface = struct {
    impl: *anyopaque,
    inbox: *Inbox,
    ctx: *Context,
    completion: xev.Completion = undefined,
    arena_state: std.heap.ArenaAllocator,

    deinitFnPtr: *const fn (ptr: *anyopaque) anyerror!void,

    const Self = @This();

    pub fn create(
        allocator: Allocator,
        engine: *Engine,
        comptime ActorType: type,
        options: ActorOptions,
    ) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .arena_state = std.heap.ArenaAllocator.init(allocator),
            .deinitFnPtr = makeTypeErasedDeinitFn(ActorType),
            .inbox = undefined,
            .ctx = undefined,
            .impl = undefined,
        };
        errdefer self.arena_state.deinit();
        const ctx = try Context.init(
            self.arena_state.allocator(),
            engine,
            self,
            options.id,
        );
        self.ctx = ctx;
        self.impl = try ActorType.init(ctx, self.arena_state.allocator());
        self.inbox = try Inbox.init(self.arena_state.allocator(), options.capacity);

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
                const maybe_envelope = inner_self.inbox.dequeue() catch {
                    inner_self.deinitFnPtr(inner_self.impl) catch |err| {
                        std.log.err("Failed to deinit actor: {s}", .{@errorName(err)});
                        return .disarm;
                    };
                    loop.timer(c, 0, ud, inner);
                    return .disarm;
                };
                if (maybe_envelope) |envelope| {
                    const actor_impl = @as(*ActorType, @ptrCast(@alignCast(inner_self.impl)));
                    actor_impl.receive(envelope) catch {
                        inner_self.deinitFnPtr(inner_self.impl) catch |err| {
                            std.log.err("Failed to deinit actor: {s}", .{@errorName(err)});
                            return .disarm;
                        };
                        return .disarm;
                    };
                    loop.timer(c, 0, ud, inner);
                    return .disarm;
                }

                loop.timer(c, 0, ud, inner);
                return .disarm;
            }
        }.inner;
        self.ctx.engine.loop.timer(&self.completion, 0, @ptrCast(self), listenForMessagesFn);
    }

    pub fn cleanupFrameworkResources(self: *Self) void {
        self.inbox.deinit();
        self.arena_state.deinit();
    }

    pub fn send(self: *Self, sender: ?*ActorInterface, msg: []const u8) !void {
        try self.inbox.enqueue(Envelope.init(
            if (sender) |s| s.ctx.actor_id else null,
            msg,
        ));
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
            } else {
                return error.ActorDoesNotHaveDeinitMethod;
            }
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
