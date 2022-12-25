const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

pub fn main() !void {
    const BUFFER_SIZE = 9999;
    var buffer: [BUFFER_SIZE]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const msg = "Perkeleen synkkää. tule tiimiimme jos sinua kiinnostaa funktionaalisuus ja nopeasti koodaaminen. t. Macho,MMong,Manager ja Mikko. Ps tykitellään";
    const coded = try b64encode(msg,allocator);
    print("msg encoded \nmsg => {s}\n\n",.{coded});
    defer allocator.free(coded);
    const decoded = try b64decode(coded,allocator); 
    print("msg decoded \ndecoded => {s} \n",.{decoded});
    defer allocator.free(decoded);
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

pub fn b64decode(str: []const u8, allocator : Allocator) ![]const u8{
    const bufferSize = str.len;
    const buffer = try allocator.alloc(u8, bufferSize);
    var bufferIndex : u32 = 0;

    var i : u32 = 0;
    // form a sextets group size 4 so that you have 24 bits in total
    // then form a octets group 8 x 3 
    while (i < str.len) : (i += 4) {
        var sex = std.mem.indexOf(u8, chars, &[1]u8{str[i]}).? << 18;    // 19
        if(i+1 < str.len and str[i+1] != '='){
            sex += std.mem.indexOf(u8, chars, &[1]u8{str[i+1]}).? << 12;
        }
        if(i+2 < str.len and str[i+2] != '='){
            sex += std.mem.indexOf(u8, chars, &[1]u8{str[i+2]}).? << 6;
        }
        if(i+3 < str.len and str[i+3] != '='){
            sex += std.mem.indexOf(u8, chars, &[1]u8{str[i+3]}).?;
        }
        var octets = [_]usize{(sex >> 16) & 255,(sex >> 8) & 255,sex & 255}; 

        for (octets) |os| {
            const o = @intCast(u8, os);
            // ascii 0 == nul. 
            if(os == 0){
                break;
            }
            if (bufferIndex >= bufferSize){
                return AllocationError.OutOfMemory;
            }
            buffer[bufferIndex] = @intCast(u8, o);
            bufferIndex += 1;
        }
    }
    var xaa = "\xaa";
    const res = std.mem.trim(u8, buffer, xaa);
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

test "b64encode large test" {
    const BUFFER_SIZE = 9999;
    var buffer: [BUFFER_SIZE]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const str = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make";
    const res = try b64encode(str, allocator);
    const expected = "TG9yZW0gSXBzdW0gaXMgc2ltcGx5IGR1bW15IHRleHQgb2YgdGhlIHByaW50aW5nIGFuZCB0eXBlc2V0dGluZyBpbmR1c3RyeS4gTG9yZW0gSXBzdW0gaGFzIGJlZW4gdGhlIGluZHVzdHJ5J3Mgc3RhbmRhcmQgZHVtbXkgdGV4dCBldmVyIHNpbmNlIHRoZSAxNTAwcywgd2hlbiBhbiB1bmtub3duIHByaW50ZXIgdG9vayBhIGdhbGxleSBvZiB0eXBlIGFuZCBzY3JhbWJsZWQgaXQgdG8gbWFrZQ==";
    try std.testing.expectEqualStrings(res, expected);
}

test "b64decode test" {
    const BUFFER_SIZE = 100;
    var buffer: [BUFFER_SIZE]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const man = try b64decode("TWFu", allocator);
    try std.testing.expectEqualStrings(man, "Man");
    allocator.free(man);
    const many = try b64decode("TWFueQ==", allocator);
    try std.testing.expectEqualStrings(many, "Many");
}

test "b64decode large test" {
    const BUFFER_SIZE = 9999;
    var buffer: [BUFFER_SIZE]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const str = "TG9yZW0gSXBzdW0gaXMgc2ltcGx5IGR1bW15IHRleHQgb2YgdGhlIHByaW50aW5nIGFuZCB0eXBlc2V0dGluZyBpbmR1c3RyeS4gTG9yZW0gSXBzdW0gaGFzIGJlZW4gdGhlIGluZHVzdHJ5J3Mgc3RhbmRhcmQgZHVtbXkgdGV4dCBldmVyIHNpbmNlIHRoZSAxNTAwcywgd2hlbiBhbiB1bmtub3duIHByaW50ZXIgdG9vayBhIGdhbGxleSBvZiB0eXBlIGFuZCBzY3JhbWJsZWQgaXQgdG8gbWFrZQ==";
    const res = try b64decode(str, allocator);
    const expected = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make";
    try std.testing.expectEqualStrings(res, expected);
}


test "test both" {
    const BUFFER_SIZE = 9999;
    var buffer: [BUFFER_SIZE]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const msg = "Perkeleen synkkää. tule tiimiimme jos sinua kiinnostaa funktionaalisuus ja nopeasti koodaaminen. t. Macho,MMong,Manager ja Mikko. Ps tykitellään";
    const coded = try b64encode(msg,allocator);
    defer allocator.free(coded);
    const decoded = try b64decode(coded,allocator); 
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(msg, decoded);
}