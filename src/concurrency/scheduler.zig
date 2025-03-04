const c = @cImport({
    @cInclude("neco.h");
});

pub const Scheduler = struct {
    wg: ?*c.neco_waitgroup = undefined,

    const Self = @This();
    pub fn init(wg: ?*c.neco_waitgroup) Self {
        return Self{ .wg = wg };
    }
    pub fn yield(_: *const Self) void {
        _ = c.neco_yield();
    }
    pub fn add(self: *const Self, delta: i64) void {
        if (self.wg) |wg| {
            _ = c.neco_waitgroup_add(wg, @intCast(delta));
        }
    }
    pub fn done(self: *const Self) void {
        if (self.wg) |wg| {
            _ = c.neco_waitgroup_done(wg);
        }
    }
    pub fn wait(self: *const Self) void {
        if (self.wg) |wg| {
            _ = c.neco_waitgroup_wait(wg);
        }
    }
    pub fn get_coroutine_id(_: *const Self) i64 {
        return @intCast(c.neco_getid());
    }
    pub fn get_last_coroutine_id(_: *const Self) i64 {
        return @intCast(c.neco_lastid());
    }
    pub fn suspend_routine(_: *const Self) void {
        _ = c.neco_suspend();
    }
    pub fn resume_routine(_: *const Self, id: i64) void {
        _ = c.neco_resume(@intCast(id));
    }

    pub fn sleep(_: *const Self, ns: i64) void {
        _ = c.neco_sleep(@intCast(ns));
    }
};
