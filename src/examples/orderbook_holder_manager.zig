const std = @import("std");
const backstage = @import("backstage");
const testing = std.testing;
const concurrency = backstage.concurrency;
const obHolder = @import("orderbook_holder.zig");
const Allocator = std.mem.Allocator;
const Context = backstage.Context;
const OrderbookHolder = obHolder.OrderbookHolder;
const OrderbookHolderMessage = obHolder.OrderbookHolderMessage;
const Envelope = backstage.Envelope;

pub const OrderbookHolderManagerMessage = union(enum) {
    spawn_holder: struct { id: []const u8 },
    start_all_holders: struct {},
};

pub const OrderbookHolderManager = struct {
    ctx: *Context,

    const Self = @This();
    pub fn init(ctx: *Context, allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .ctx = ctx,
        };
        return self;
    }

    pub fn receive(self: *Self, message: *const Envelope(OrderbookHolderManagerMessage)) !void {
        switch (message.payload) {
            .spawn_holder => |m| {
                const holder = try self.ctx.spawnChildActor(OrderbookHolder, OrderbookHolderMessage, .{
                    .id = m.id,
                });
                try holder.send(self.ctx.actor, OrderbookHolderMessage{ .init = .{ .ticker = m.id } });
            },
            .start_all_holders => |_| {
                for (self.ctx.child_actors.items) |actor| {
                    try actor.send(self.ctx.actor, OrderbookHolderMessage{ .start = .{} });
                }
            },
        }
    }
};
