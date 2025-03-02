const c = @cImport({
    @cInclude("neco.h");
});

pub const Scheduler = struct {
    wg: ?*c.neco_waitgroup = undefined,

    pub fn init(wg: ?*c.neco_waitgroup) @This() {
        return @This(){ .wg = wg };
    }
    pub fn yield(_: @This()) void {
        _ = c.neco_yield();
    }
    pub fn add(self: @This(), delta: i64) void {
        if (self.wg) |wg| {
            _ = c.neco_waitgroup_add(wg, @intCast(delta));
        }
    }
    pub fn done(self: @This()) void {
        if (self.wg) |wg| {
            _ = c.neco_waitgroup_done(wg);
        }
    }
    pub fn wait(self: @This()) void {
        if (self.wg) |wg| {
            _ = c.neco_waitgroup_wait(wg);
        }
    }
    pub fn suspend_routine(_: @This()) void {
        _ = c.neco_suspend();
    }
    pub fn resume_routine(_: @This(), id: i64) void {
        _ = c.neco_resume(@intCast(id));
    }
};
