const std = @import("std");
const inbox = @import("inbox.zig");
const concurrency = @import("concurrency/root.zig");
const eng = @import("engine.zig");
const ctxt = @import("context.zig");

const Allocator = std.mem.Allocator;
const Inbox = inbox.Inbox;
const Coroutine = concurrency.Coroutine;
const Scheduler = concurrency.Scheduler;
const Engine = eng.Engine;
const Context = ctxt.Context;

pub const ActorInterface = struct {
    ptr: *anyopaque,
    inbox: Inbox,
    ctx: *Context,

    receiveFnPtr: *const fn (ptr: *anyopaque, msg: *const anyopaque) anyerror!void,
    deinitFnPtr: *const fn (ptr: *anyopaque) void,

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
            .inbox = try Inbox.init(MsgType, capacity),
            .ctx = ctx,
            .receiveFnPtr = makeTypeErasedReceiveFn(ActorType, MsgType),
            .deinitFnPtr = makeTypeErasedDeinitFn(ActorType),
        };
        ctx.self = self;

        Coroutine(makeRoutineFn(MsgType)).go(self);

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.inbox.deinit();
        self.deinitFnPtr(self.ptr);
    }

    pub fn send(self: *const Self, msg: anytype) !void {
        try self.inbox.send(msg);
    }
};

pub fn makeRoutineFn(comptime MsgType: type) fn (*ActorInterface) anyerror!void {
    return struct {
        fn routine(self: *ActorInterface) !void {
            var msg: MsgType = undefined;
            while (true) {
                try self.inbox.receive(&msg);
                try self.receiveFnPtr(self.ptr, &msg);
            }
        }
    }.routine;
}

fn makeTypeErasedReceiveFn(comptime ActorType: type, comptime MsgType: type) fn (*anyopaque, *const anyopaque) anyerror!void {
    return struct {
        fn wrapper(ptr: *anyopaque, msg: *const anyopaque) anyerror!void {
            const self = @as(*ActorType, @ptrCast(@alignCast(ptr)));
            const typed_msg = @as(*const MsgType, @ptrCast(@alignCast(msg)));
            try ActorType.receive(self, typed_msg);
        }
    }.wrapper;
}

fn makeTypeErasedDeinitFn(comptime ActorType: type) fn (*anyopaque) void {
    return struct {
        fn wrapper(ptr: *anyopaque) void {
            const self = @as(*ActorType, @ptrCast(@alignCast(ptr)));
            if (comptime hasDeinitMethod(ActorType)) {
                ActorType.deinit(self);
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

        if (fieldInfo != .Fn) continue;

        const FnInfo = fieldInfo.Fn;
        if (FnInfo.params.len != 1) continue;

        const ParamType = FnInfo.params[0].type.?;
        if (ParamType != *T) continue;

        return true;
    }

    return false;
}
