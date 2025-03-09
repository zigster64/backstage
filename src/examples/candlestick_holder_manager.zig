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
    spawn_holder: struct { id: []const u8 },
    start_all_holders: struct {},
};

pub const CandlestickManager = struct {
    ctx: *Context,

    const Self = @This();
    pub fn init(ctx: *Context, allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .ctx = ctx,
        };
        return self;
    }

    pub fn receive(self: *Self, message: *const CandlestickHolderManagerMessage) !void {
        switch (message.*) {
            .spawn_holder => |m| {
                const holder = try self.ctx.spawnChildActor(CandlestickHolder, CandlestickHolderMessage, .{
                    .id = m.id,
                });
                try holder.send(CandlestickHolderMessage{ .init = .{ .ticker = m.id } });
            },
            .start_all_holders => |_| {
                for (self.ctx.child_actors.items) |actor| {
                    try actor.send(CandlestickHolderMessage{ .start = .{} });
                }
            },
        }
    }
};
