// const std = @import("std");
// const eng = @import("engine.zig");
// const act = @import("actor.zig");
// const msg = @import("message.zig");

// const Engine = eng.Engine;
// const ActorInterface = act.ActorInterface;

// // TODO: Actors should register themselves with the engine. When doing so they should provide what sort of messages they are interested in.
// // The engine will then only send messages of the correct type to the actor.

// // This is an example of a simple actor that receives messages and processes them.
// pub const CandlesticksActor = struct {
//     candlesticks: std.ArrayList(Candlestick),

//     pub fn init(allocator: std.mem.Allocator) !*CandlesticksActor {
//         const self = try allocator.create(CandlesticksActor);
//         self.* = .{
//             .candlesticks = std.ArrayList(Candlestick).init(allocator),
//         };
//         return self;
//     }

//     pub fn deinit(self: *CandlesticksActor, allocator: std.mem.Allocator) void {
//         self.candlesticks.deinit();
//         allocator.destroy(self);
//     }

//     pub fn receive(_: *CandlesticksActor, message: *const CandlesticksMessage) void {
//         switch (message.*) {
//             .candlestick => |candlestick| {
//                 std.debug.print("Received Candlestick:\n  open: {}\n  high: {}\n  low: {}\n  close: {}\n", .{ candlestick.open, candlestick.high, candlestick.low, candlestick.close });
//             },
//             .test_msg => |test_msg| {
//                 std.debug.print("Received Test Message:\n  example: {s}\n", .{test_msg.example});
//             },
//         }
//     }
// };
