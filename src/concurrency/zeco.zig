const std = @import("std");
const coroutine = @import("coroutine.zig");
const EmptyArgs = @import("root.zig").EmptyArgs;
const c = @cImport({
    @cInclude("neco.h");
});

const Coroutine = coroutine.Coroutine;
const Context = coroutine.Context;

pub fn run(mainRoutine: fn (ctx: *Context, args: EmptyArgs) anyerror!void) void {
    const ctx = Context{};
    _ = c.neco_start(
        Coroutine(mainRoutine).inner,
        1,
        &ctx,
    );
}
pub fn run_and_block(mainRoutine: fn (ctx: *Context, _: void) anyerror!void) void {
    var global_wg = std.mem.zeroes(c.neco_waitgroup);
    _ = c.neco_waitgroup_init(&global_wg);
    _ = c.neco_waitgroup_add(&global_wg, @intCast(10));
    const ctx = Context{ .wg = &global_wg };

    const wg_main_routine_wrapper = struct {
        fn inner(ci: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
            Coroutine.init(mainRoutine, .{}).inner(ci, argv);
            _ = c.neco_suspend();
        }
    }.inner;

    _ = c.neco_start(
        wg_main_routine_wrapper,
        1,
        &ctx,
    );
}
