const std = @import("std");
const c = @cImport({
    @cInclude("neco.h");
});

fn p(s: []const u8) void {
    std.debug.print("HERE: {s}\n", .{s});
}

pub fn init() void {
    // this causes crashing here, when started in a coroutine.
    _ = c.neco_start(neco_main, 0);
}

pub fn start() void {}

fn neco_main(_: c_int, _: [*c]?*anyopaque) callconv(.C) void {
    const N = 5;

    p("1");
    var wg: c.neco_waitgroup = std.mem.zeroes(c.neco_waitgroup);
    _ = c.neco_waitgroup_init(&wg);
    _ = c.neco_waitgroup_add(&wg, N);

    p("2");
    // Start coroutines with index
    const startTime = c.neco_now();
    for (0..N) |i| {
        var index = i; // Create a mutable copy
        const args = [_]?*anyopaque{ @ptrCast(&wg), @ptrCast(&index) };
        _ = c.neco_start(coro, 2, &args);
    }

    p("3");
    // Wait for all coroutines to start
    _ = c.neco_waitgroup_wait(&wg);

    p("4");
    const elapsed: i64 = c.neco_now() - startTime;
    const fElapsed: f64 = @floatFromInt(elapsed);
    const fDiv: f64 = 1_000_000.0;

    // OK
    _ = c.printf("all started in %f ms\n", fElapsed / fDiv);
}

fn coro(_: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
    const wg: *c.neco_waitgroup = @alignCast(@ptrCast(argv[0]));
    const index = @as(usize, @intFromPtr(argv[1])); // Pass the value directly instead of as a pointer

    _ = c.neco_waitgroup_done(wg);
    _ = c.neco_waitgroup_wait(wg);

    // Add infinite loop with coroutine number
    while (true) {
        std.debug.print("Looping forever in coroutine #{d}!\n", .{index});
        _ = c.neco_yield(); // Yield to allow other coroutines to run
    }
}
