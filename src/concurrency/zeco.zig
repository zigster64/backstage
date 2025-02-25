const std = @import("std");
const coroutine = @import("coroutine.zig");
const c = @cImport({
    @cInclude("neco.h");
});

const Coroutine = coroutine.Coroutine;

pub fn init(mainRoutine: Coroutine) void {
    _ = c.neco_start(mainRoutine, 0);
}
