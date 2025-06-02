# Backstage: Actor Framework for Zig

Backstage is a high-performance, event-driven actor framework for the Zig programming language. Built on top of [libxev](https://github.com/mitchellh/libxev), it provides a robust foundation for building concurrent applications using the actor model pattern.

The main goal of this project is to gain deeper understanding of the programming language while building something practical and useful. By implementing an actor framework from scratch, this project explores:

- **Event-Driven Architecture**: Built on libxev for high-performance, non-blocking I/O operations
- **Actor Lifecycle Management**: Automated actor supervision with parent-child relationships
- **Memory Efficient**: Careful memory management with configurable inbox capacities
- **Actor Registry**: Built-in registry for actor discovery and management
- **Concurrent programming patterns**: Built to be run on a single core yet handle concurrent workloads

## Architecture

The framework consists of several core components:

- **Engine**: The central runtime that manages the event loop and actor lifecycle
- **ActorInterface**: Type-erased interface for actor communication and management
- **Context**: Provides actors with access to the engine and manages parent-child relationships
- **Registry**: Maps actor IDs and message types to actor instances
- **Inbox**: Thread-safe message queue with configurable capacity
- **Envelope**: Message wrapper that includes sender information for reply patterns

## Installation

Add Backstage to your `build.zig.zon`:

```zig
.dependencies = .{
    .backstage = .{
        .url = "https://github.com/Thomvanoorschot/backstage/archive/main.tar.gz",
        .hash = "...", // Update with actual hash
    },
},
```

Or use zig fetch:

```bash
zig fetch --save https://github.com/Thomvanoorschot/backstage/archive/main.tar.gz
```

## Quick Start

```zig
const std = @import("std");
const backstage = @import("backstage");

// Define your message
pub const ListenToTheseMessages = union(enum) {
    init: InitMessage,
};

pub const InitMessage = struct {
    example: []const u8,
}

// Define your actor
const MyActor = struct {
    ctx: *backstage.Context,
    allocator: std.mem.Allocator,

    const Self = @This();
    pub fn init(ctx: *backstage.Context, allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .ctx = ctx,
            .allocator = allocator,
        };
        return self;
    }

    pub fn receive(self: *Self(), envelope: *const backstage.Envelope(ListenToTheseMessages)) !void {
        switch (message.payload) {
            .init => |m| {
                std.log.info("Received message {}", .{m});
            }
        }
    }

    pub fn deinit(self: *Self) !void {
        try self.ctx.deinit();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize the engine
    var engine = try backstage.Engine.init(allocator);
    defer engine.deinit();

    // Spawn an actor
    const actor = try engine.spawnActor(MyActor, []const u8, .{
        .id = "my-actor",
        .capacity = 1024,
    });

    // Send a message
    try engine.send(null, "other_arbitrary_actor_id", ListenToTheseMessages{ .init = .{ .example = "Hello, World!" } });

    // Run the event loop
    try engine.run();
}
```

## Examples

For comprehensive examples and real-world usage, see the [Zigma algorithmic trading framework](https://github.com/Thomvanoorschot/zigma), which demonstrates advanced patterns.

## API Reference

### Engine

The `Engine` is the central component that manages the actor system:

- `init(allocator)` - Initialize a new engine instance
- `spawnActor(ActorType, MsgType, options)` - Create and register a new actor
- `send(sender, id, message)` - Send a message to a specific actor by ID
- `broadcast(sender, message)` - Broadcast a message to all actors that handle the message type
- `run()` - Start the event loop
- `deinit()` - Clean up resources

### Actor Interface

Actors must implement:

- `init(ctx, allocator)` - Actor initialization
- `receive(envelope)` - Message handling
- `deinit()` - Optional cleanup (automatically detected)

## Design Principles

- **Isolation**: Actors maintain their own state and communicate only through messages
- **Supervision**: Parent actors manage child actor lifecycles
- **Performance**: Zero-allocation message passing in steady state
- **Type Safety**: Compile-time message type checking
- **Resource Management**: Automatic cleanup of actor hierarchies

## Current Status

This is an early-stage implementation, focusing on core actor framework concepts. The project is primarily meant as a learning exercise and may evolve significantly as understanding of both the language and actor patterns deepens.

## License

MIT License - see LICENSE file for details.