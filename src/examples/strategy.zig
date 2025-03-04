const std = @import("std");
const alphazig = @import("alphazig");
const testing = std.testing;
const concurrency = alphazig.concurrency;

const Allocator = std.mem.Allocator;
const Context = alphazig.Context;

// This is an example of a message that can be sent to the CandlesticksActor.
pub const StrategyMessage = union(enum) {
    init: struct {},
    do_nothing: struct { some_field: i64 },
    continue_routine: struct { some_field: SomeField },
};
// make some_field a more complex object which can't get stored on a global const section
const SomeField = struct {
    some_field: []const u8,
};

pub const Strategy = struct {
    ctx: *Context,
    coroutine_id: i64,
    const Self = @This();

    pub fn init(ctx: *Context, allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .ctx = ctx,
            .coroutine_id = 0,
        };
        return self;
    }

    pub fn receive(self: *Self, message: *const StrategyMessage) !void {
        switch (message.*) {
            .init => |_| {
                std.debug.print("Sending once\n", .{});
                try self.ctx.send("not_processing_actor", StrategyMessage{ .do_nothing = .{ .some_field = 123 } });
                try self.ctx.send("not_processing_actor", StrategyMessage{ .do_nothing = .{ .some_field = 123 } });
                try self.ctx.send("not_processing_actor", StrategyMessage{ .do_nothing = .{ .some_field = 123 } });
                try self.ctx.send("not_processing_actor", StrategyMessage{ .continue_routine = .{ .some_field = SomeField{ .some_field = "123" } } });
                try self.ctx.send("not_processing_actor", StrategyMessage{ .continue_routine = .{ .some_field = SomeField{ .some_field = "123" } } });
                std.debug.print("Sending twice\n", .{});
            },
            .do_nothing => |_| {
                self.ctx.sleepRoutine(2000000000);
            },
            .continue_routine => |m| {
                std.debug.print("Continuing routine {s}\n", .{m.some_field.some_field});
                self.ctx.resumeRoutine(self.coroutine_id);
            },
        }
    }
};
