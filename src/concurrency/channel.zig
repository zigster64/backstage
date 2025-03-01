const std = @import("std");
const c = @cImport({
    @cInclude("neco.h");
});

pub const Channel = struct {
    chan: *c.neco_chan,
    data_size: usize,

    pub const Error = error{
        OutOfMemory,
        InvalidParameter,
        PermissionDenied,
        Canceled,
        Closed,
        Empty,
    };

    pub fn init(comptime T: type, capacity: usize) Error!Channel {
        var chan: ?*c.neco_chan = undefined;
        const result = c.neco_chan_make(&chan, @sizeOf(T), capacity);

        return switch (result) {
            c.NECO_OK => Channel{
                .chan = chan.?,
                .data_size = @sizeOf(T),
            },
            c.NECO_NOMEM => Error.OutOfMemory,
            c.NECO_INVAL => Error.InvalidParameter,
            c.NECO_PERM => Error.PermissionDenied,
            else => Error.InvalidParameter,
        };
    }

    pub fn deinit(self: Channel) void {
        self.release() catch {};
    }

    pub fn retain(self: Channel) Error!void {
        const result = c.neco_chan_retain(self.chan);
        return switch (result) {
            c.NECO_OK => {},
            c.NECO_INVAL => Error.InvalidParameter,
            c.NECO_PERM => Error.PermissionDenied,
            else => Error.InvalidParameter,
        };
    }

    pub fn release(self: Channel) Error!void {
        const result = c.neco_chan_release(self.chan);
        return switch (result) {
            c.NECO_OK => {},
            c.NECO_INVAL => Error.InvalidParameter,
            c.NECO_PERM => Error.PermissionDenied,
            else => Error.InvalidParameter,
        };
    }

    pub fn send(self: Channel, data: anytype) Error!void {
        if (@sizeOf(@TypeOf(data)) != self.data_size) {
            return Error.InvalidParameter;
        }
        const result = c.neco_chan_send(self.chan, @ptrCast(@constCast(&data)));
        return switch (result) {
            c.NECO_OK => {},
            c.NECO_PERM => Error.PermissionDenied,
            c.NECO_INVAL => Error.InvalidParameter,
            c.NECO_CANCELED => Error.Canceled,
            c.NECO_CLOSED => Error.Closed,
            else => Error.InvalidParameter,
        };
    }

    pub fn receive(self: Channel, data: anytype) Error!void {
        const T = @TypeOf(data.*);

        if (@sizeOf(T) != self.data_size) {
            std.log.err("Size mismatch: channel expects {d} bytes but got {d} bytes", .{
                self.data_size,
                @sizeOf(T),
            });
            return Error.InvalidParameter;
        }

        const void_ptr: ?*anyopaque = @ptrCast(data);
        const result = c.neco_chan_recv(self.chan, void_ptr);
        return switch (result) {
            c.NECO_OK => {},
            c.NECO_PERM => Error.PermissionDenied,
            c.NECO_INVAL => Error.InvalidParameter,
            c.NECO_CANCELED => Error.Canceled,
            c.NECO_CLOSED => Error.Closed,
            else => Error.InvalidParameter,
        };
    }

    pub fn tryReceive(self: Channel, data: anytype) Error!void {
        if (@sizeOf(@TypeOf(data.*)) != self.data_size) {
            return Error.InvalidParameter;
        }

        const result = c.neco_chan_tryrecv(self.chan, data);
        return switch (result) {
            c.NECO_OK => {},
            c.NECO_EMPTY => Error.Empty,
            c.NECO_CLOSED => Error.Closed,
            c.NECO_PERM => Error.PermissionDenied,
            c.NECO_INVAL => Error.InvalidParameter,
            else => Error.InvalidParameter,
        };
    }

    pub fn broadcast(self: Channel, data: anytype) Error!usize {
        if (@sizeOf(@TypeOf(data)) != self.data_size) {
            return Error.InvalidParameter;
        }

        const result = c.neco_chan_broadcast(self.chan, @ptrCast(@constCast(&data)));
        return switch (result) {
            c.NECO_CLOSED => Error.Closed,
            c.NECO_PERM => Error.PermissionDenied,
            c.NECO_INVAL => Error.InvalidParameter,
            else => if (result >= 0) @intCast(result) else Error.InvalidParameter,
        };
    }

    pub fn close(self: Channel) Error!void {
        const result = c.neco_chan_close(self.chan);
        return switch (result) {
            c.NECO_OK => {},
            c.NECO_PERM => Error.PermissionDenied,
            c.NECO_INVAL => Error.InvalidParameter,
            c.NECO_CLOSED => Error.Closed,
            else => Error.InvalidParameter,
        };
    }
};
