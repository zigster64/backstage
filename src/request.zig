
// TODO This needs to be reimplemented
pub fn Request(comptime PayloadType: type) type {
    return struct {
        payload: PayloadType,
    };
}
