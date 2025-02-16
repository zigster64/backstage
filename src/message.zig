// pub const MessageInterface = struct {
//     ptr: *anyopaque,
//     data: *const anyopaque,
//     type_info: type,

//     pub fn init(id: u64, data: anytype) MessageInterface {
//         const T = @TypeOf(data);
//         return .{
//             .id = id,
//             .data = @ptrCast(&data),
//             .type_info = T,
//         };
//     }

//     pub fn get(self: MessageInterface, comptime T: type) ?T {
//         if (self.type_info != T) {
//             return null;
//         }
//         return @as(*const T, @ptrCast(self.data)).*;
//     }
// };
