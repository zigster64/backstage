const std = @import("std");
const c = @cImport({
    @cInclude("neco.h");
});

pub fn init() void {
    _ = c.neco_start(neco_main, 0);
}


fn neco_main(_: c_int, _: [*c]?*anyopaque) callconv(.C) void {
    var wg: c.neco_waitgroup = std.mem.zeroes(c.neco_waitgroup);
    _ = c.neco_waitgroup_init(&wg);

    Coroutine.spawn(.{}, parameterized_task, .{ .x = 42, .message = "Hello, world!" });

    _ = c.neco_waitgroup_wait(&wg);
}

fn simple_task(ctx: Context) void {
    while (true) {
        std.debug.print("Simple task running!\n", .{});
        ctx.yield();
    }
}

fn parameterized_task(ctx: Context, args: struct { x: i32, message: []const u8 }) void {
    while (true) {
        std.debug.print("Got number {d} and message: {s}\n", .{ args.x, args.message });
        ctx.yield();
    }
}

pub const Context = struct {
    wg: *c.neco_waitgroup = undefined,

    pub fn yield(_: Context) void {
        _ = c.neco_yield();
    }

    pub fn done(self: Context) void {
        _ = c.neco_waitgroup_done(self.wg);
    }
};

pub const Coroutine = struct {
    wg: Context,

    pub fn spawn(ctx: Context, comptime function: anytype, args: anytype) void {
        var args_owned = args;

        var c_args: [2]?*const anyopaque = undefined;
        c_args[0] = @ptrCast(&ctx);
        c_args[1] = @ptrCast(&args_owned);

        const func = struct {
            fn inner(_: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
                const inner_ctx = @as(*const Context, @ptrCast(@alignCast(argv[0]))).*;
                if (argv[1] == null) {
                    @panic("argument pointer is null");
                }
                const inner_args = @as(*const @TypeOf(args), @ptrCast(@alignCast(argv[1]))).*;
                function(inner_ctx, inner_args);
            }
        }.inner;

        _ = c.neco_start(func, @intCast(c_args.len), &c_args);
    }

    pub fn wait(self: *Coroutine) void {
        _ = c.neco_waitgroup_wait(&self.wg);
    }

    pub fn done(self: *Coroutine) void {
        _ = c.neco_waitgroup_done(&self.wg);
    }
};
