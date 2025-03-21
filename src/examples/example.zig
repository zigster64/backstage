const std = @import("std");
const backstage = @import("backstage");
const testing = std.testing;
const concurrency = backstage.concurrency;
const obHolderManager = @import("orderbook_holder_manager.zig");
const obHolder = @import("orderbook_holder.zig");
const strg = @import("strategy.zig");

const Allocator = std.mem.Allocator;
const Engine = backstage.Engine;
const Context = backstage.Context;
const ActorInterface = backstage.ActorInterface;
const Coroutine = concurrency.Coroutine;
const Scheduler = concurrency.Scheduler;
const Channel = concurrency.Channel;
const EmptyArgs = concurrency.EmptyArgs;

const OrderbookHolder = obHolder.OrderbookHolder;
const OrderbookHolderMessage = obHolder.OrderbookHolderMessage;
const Strategy = strg.Strategy;
const StrategyMessage = strg.StrategyMessage;
const OrderbookHolderManager = obHolderManager.OrderbookHolderManager;
const OrderbookHolderManagerMessage = obHolderManager.OrderbookHolderManagerMessage;

pub fn main() !void {
    concurrency.run(mainRoutine);
}
pub fn mainRoutine(_: EmptyArgs) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    const orderbook_holder_manager = try engine.spawnActor(OrderbookHolderManager, OrderbookHolderManagerMessage, .{
        .id = "holder_manager",
    });
    try orderbook_holder_manager.send(null, OrderbookHolderManagerMessage{ .spawn_holder = .{ .id = "BTC/USD" } });
    try orderbook_holder_manager.send(null, OrderbookHolderManagerMessage{ .start_all_holders = .{} });

    const strategy = try engine.spawnActor(Strategy, StrategyMessage, .{
        .id = "strategy",
    });
    try strategy.send(null, StrategyMessage{ .init = .{} });
    try strategy.send(null, StrategyMessage{ .request = .{} });

    // This is only done to permanently suspend the main routine so it doesn't run out of scope.
    strategy.ctx.suspendRoutine();
}
