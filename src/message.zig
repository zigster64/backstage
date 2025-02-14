pub fn Message(comptime T: type) type {
    return struct {
        id: u64,
        data: T,
    };
}
