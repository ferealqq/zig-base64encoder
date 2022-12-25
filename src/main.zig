const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

pub fn main() !void {
    const BUFFER_SIZE = 100;
    var buffer: [BUFFER_SIZE]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const result = try b64encode("Man",allocator);
    print("man = {s} ", .{result});
    allocator.free(result);
    const res = try b64encode("Many",allocator);
    print("many = {s} \n", .{res});
    allocator.free(res);
}

const AllocationError = error {
    OutOfMemory,
};

pub fn b64encode(str: []const u8, allocator : Allocator) ![]const u8 {
    const len = str.len;
    var bufferIndex : u32 = 0;
    // approximation of the length needed for the result buffer. 
    const bufferSize = len*3;
    var resultBuffer = try allocator.alloc(u8, bufferSize);
    var padding : usize = len % 3;

    var i : u8 = 0; 
    while (i < len) : (i += 3) {
        // form a 24-bit group
        var octets : usize = (@intCast(usize, str[i]) << 16);
        if (i+1 < len){
            octets += @intCast(usize, str[i+1]) << 8; 
        }
        if (i+2 < len){
            octets += @intCast(usize, str[i+2]);
        }
        // split the 24-bit group to sextets. 
        var s : [4]usize = [_]usize{(octets >> 18) & 63, (octets >> 12) & 63, (octets >> 6) & 63, octets & 63};
        for (s) |c,j| {
            if (i+j > len){
                break;
            }
            resultBuffer[bufferIndex] = chars[c];
            // check that the resultBuffer isn't full.
            if (bufferIndex >= bufferSize){
                return AllocationError.OutOfMemory;
            }
            bufferIndex += 1;
        }
    }
    if (padding == 0){
        // trim whitespaces
        var xaa = "\xaa";
        const res = std.mem.trim(u8, resultBuffer, xaa);
        return res;
    }

    while (3 > padding) : (padding += 1) {
        if(bufferIndex >= bufferSize){
            return AllocationError.OutOfMemory;
        }
        resultBuffer[bufferIndex] = '=';
        bufferIndex += 1;
    }
    // trim whitespaces
    var xaa = "\xaa";
    const res = std.mem.trim(u8, resultBuffer, xaa);
    return res;
}

test "b64encode test" {
    const BUFFER_SIZE = 100;
    var buffer: [BUFFER_SIZE]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    var res1 = try b64encode("Many",allocator);
    try std.testing.expectEqualStrings(res1, "TWFueQ==");
    allocator.free(res1);
    const res2 = try b64encode("Webson mafia",allocator);
    try std.testing.expectEqualStrings(res2, "V2Vic29uIG1hZmlh");
    allocator.free(res2);
}

test "b64encode large" {
    const BUFFER_SIZE = 9999;
    var buffer: [BUFFER_SIZE]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const str = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make";
    const res = try b64encode(str, allocator);
    const expected = "TG9yZW0gSXBzdW0gaXMgc2ltcGx5IGR1bW15IHRleHQgb2YgdGhlIHByaW50aW5nIGFuZCB0eXBlc2V0dGluZyBpbmR1c3RyeS4gTG9yZW0gSXBzdW0gaGFzIGJlZW4gdGhlIGluZHVzdHJ5J3Mgc3RhbmRhcmQgZHVtbXkgdGV4dCBldmVyIHNpbmNlIHRoZSAxNTAwcywgd2hlbiBhbiB1bmtub3duIHByaW50ZXIgdG9vayBhIGdhbGxleSBvZiB0eXBlIGFuZCBzY3JhbWJsZWQgaXQgdG8gbWFrZQ==";
    try std.testing.expectEqualStrings(res, expected);
}