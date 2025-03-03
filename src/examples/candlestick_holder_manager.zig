const std = @import("std");
const alphazig = @import("alphazig");
const testing = std.testing;
const concurrency = alphazig.concurrency;
const csHolder = @import("candlestick_holder.zig");

const Allocator = std.mem.Allocator;
const Context = alphazig.Context;

const CandlestickHolder = csHolder.CandlestickHolder;
const CandlestickHolderMessage = csHolder.CandlestickHolderMessage;

pub const CandlestickHolderManagerMessage = union(enum) {
    start_holder: struct { id: []const u8 },
};

pub const CandlestickManager = struct {
    ctx: *Context,

    pub fn init(ctx: *Context, allocator: Allocator) !*@This() {
        const self = try allocator.create(@This());
        self.* = .{
            .ctx = ctx,
        };
        return self;
    }

    pub fn receive(self: *@This(), message: *const CandlestickHolderManagerMessage) !void {
        switch (message.*) {
            .start_holder => |m| {
                std.debug.print("Starting holder manager with {s}\n", .{m.id});
                const holder = try self.ctx.spawnChildActor(CandlestickHolder, CandlestickHolderMessage, .{
                    .id = m.id,
                });
                try holder.send(CandlestickHolderMessage{ .init = .{ .ticker = "test" } });
            },
        }
    }
};
