const std = @import("std");
const inbox = @import("inbox.zig");
const concurrency = @import("concurrency/root.zig");

const assert = std.debug.assert;
const Inbox = inbox.Inbox;
const Coroutine = concurrency.Coroutine;
const Context = concurrency.Context;

pub const ActorInterface = struct {
    arena_allocator: std.heap.ArenaAllocator,
    ptr: *anyopaque,
    inbox: Inbox,

    receiveFnPtr: *const fn (ptr: *anyopaque, msg: *const anyopaque) void,
    deinitFnPtr: *const fn (ptr: *anyopaque) void,

    pub fn init(
        parent_allocator: std.mem.Allocator,
        comptime ActorType: type,
        comptime MsgType: type,
        capacity: usize,
    ) !*@This() {
        var arena = std.heap.ArenaAllocator.init(parent_allocator);
        errdefer arena.deinit();

        const arena_allocator = arena.allocator();
        const actor_instance = try ActorType.init(&arena);

        const receiveFn = makeTypeErasedReceiveFn(ActorType, MsgType);
        const deinitFn = makeTypeErasedDeinitFn(ActorType);
        const routineFn = makeRoutineFn(MsgType);

        const self = try arena_allocator.create(@This());
        self.* = .{
            .arena_allocator = arena,
            .ptr = actor_instance,
            .inbox = try Inbox.init(MsgType, capacity),
            .receiveFnPtr = receiveFn,
            .deinitFnPtr = deinitFn,
        };
        var ctx = Context.init(null);
        Coroutine(routineFn).go(&ctx, self);

        return self;
    }

    pub fn deinit(self: *@This()) void {
        self.inbox.deinit();
        self.arena_allocator.deinit();
        self.deinitFnPtr(self.ptr);
    }

    pub fn send(self: *@This(), msg: anytype) !void {
        try self.inbox.send(msg);
    }
};

pub fn makeRoutineFn(comptime MsgType: type) fn (*Context, *ActorInterface) anyerror!void {
    return struct {
        fn routine(_: *Context, args: *ActorInterface) !void {
            var msg: MsgType = undefined;
            while (true) {
                try args.inbox.receive(&msg);
                args.receiveFnPtr(args.ptr, &msg);
            }
        }
    }.routine;
}

fn makeTypeErasedReceiveFn(comptime ActorType: type, comptime MsgType: type) fn (*anyopaque, *const anyopaque) void {
    return struct {
        fn wrapper(ptr: *anyopaque, msg: *const anyopaque) void {
            const self = @as(*ActorType, @ptrCast(@alignCast(ptr)));
            const typed_msg = @as(*const MsgType, @ptrCast(@alignCast(msg)));
            ActorType.receive(self, typed_msg);
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
