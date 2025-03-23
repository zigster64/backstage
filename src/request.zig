// const chan = @import("concurrency/channel.zig");

// const Channel = chan.Channel;
pub fn Request(comptime PayloadType: type) type {
    return struct {
        payload: PayloadType,
        // result: ?Channel = null,
    };
}
