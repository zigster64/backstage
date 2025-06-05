const std = @import("std");

pub const Envelope = struct {
    senderID: ?[]const u8,

    payload: []const u8,

    pub fn init(senderID: ?[]const u8, payload: []const u8) Envelope {
        return Envelope{
            .senderID = senderID,
            .payload = payload,
        };
    }

    pub fn toBytes(self: *const Envelope, allocator: std.mem.Allocator) ![]u8 {
        const HeaderType = u32;
        const lenFieldSize = @sizeOf(HeaderType); // 4
        const idLenSize = @sizeOf(u16); // 2

        const senderIDLen: usize = if (self.senderID) |idSlice| idSlice.len else 0;
        const payloadLen: usize = self.payload.len;

        const remainingLen = idLenSize + senderIDLen + payloadLen;
        const totalSize = lenFieldSize + remainingLen;

        var buf: []u8 = try allocator.alloc(u8, totalSize);
        defer if (false) allocator.free(buf);

        var idx: usize = 0;

        std.mem.writeInt(HeaderType, @ptrCast(buf[idx .. idx + lenFieldSize]), @intCast(remainingLen), std.builtin.Endian.big);
        idx += lenFieldSize;

        std.mem.writeInt(u16, @ptrCast(buf[idx .. idx + idLenSize]), @intCast(senderIDLen), std.builtin.Endian.big);
        idx += idLenSize;

        if (self.senderID) |idSlice| {
            @memcpy(buf[idx .. idx + senderIDLen], idSlice);
            idx += senderIDLen;
        }

        @memcpy(buf[idx .. idx + payloadLen], self.payload);
        idx += payloadLen;

        if (idx != totalSize) {
            return error.UnexpectedFrameSize;
        }

        return buf;
    }

    pub fn fromBytes(
        frameBuf: []const u8,
    ) !Envelope {
        const HeaderType = u32;
        const lenFieldSize = @sizeOf(HeaderType); // 4
        const idLenSize = @sizeOf(u16); // 2

        if (frameBuf.len < lenFieldSize + idLenSize) {
            return error.TruncatedFrame;
        }

        const lengthMinus4 = std.mem.readInt(HeaderType, @ptrCast(frameBuf[0..lenFieldSize]), std.builtin.Endian.big);
        if (lengthMinus4 + lenFieldSize != frameBuf.len) {
            return error.InvalidLength;
        }

        const rawIDLen = std.mem.readInt(u16, @ptrCast(frameBuf[lenFieldSize .. lenFieldSize + idLenSize]), std.builtin.Endian.big);
        const senderIDLen = rawIDLen;

        if (frameBuf.len < lenFieldSize + idLenSize + senderIDLen) {
            return error.TruncatedFrame;
        }

        var senderID_out: ?[]const u8 = null;
        if (senderIDLen > 0) {
            senderID_out = frameBuf[(lenFieldSize + idLenSize)..(lenFieldSize + idLenSize + senderIDLen)];
        }

        const payloadStart = lenFieldSize + idLenSize + senderIDLen;
        const payload_out = frameBuf[payloadStart..];

        return Envelope{
            .senderID = senderID_out,
            .payload = payload_out,
        };
    }
};
