const std = @import("std");
const alphazig = @import("alphazig");
const testing = std.testing;
const concurrency = alphazig.concurrency;
const csHolderManager = @import("candlestick_holder_manager.zig");
const csHolder = @import("candlestick_holder.zig");

const Allocator = std.mem.Allocator;
const Engine = alphazig.Engine;
const Context = alphazig.Context;
const ActorInterface = alphazig.ActorInterface;
const Coroutine = concurrency.Coroutine;
const Scheduler = concurrency.Scheduler;
const Channel = concurrency.Channel;
const EmptyArgs = concurrency.EmptyArgs;

const CandlestickHolderManager = csHolderManager.CandlestickManager;
const CandlestickHolderManagerMessage = csHolderManager.CandlestickHolderManagerMessage;
const CandlestickHolder = csHolder.CandlestickHolder;
const CandlestickHolderMessage = csHolder.CandlestickHolderMessage;

pub fn main() !void {
    concurrency.run(mainRoutine);
    std.debug.print("AAAAAAAAAAAAAAAAAAAAa", .{});
}
pub fn mainRoutine(_: EmptyArgs) !void {
    // ctx.add(1);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var engine = Engine.init(allocator);
    defer engine.deinit();

    const candlestick_holder_manager = try engine.spawnActor(CandlestickHolderManager, CandlestickHolderManagerMessage, .{
        .id = "holder_manager",
    });


    try candlestick_holder_manager.send(CandlestickHolderManagerMessage{ .start_holder = .{ .id = "USD_EUR" } });


    Scheduler.init(null).suspend_routine();
    std.debug.print("OUT OF SCOPE\n", .{});
}
