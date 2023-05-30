const std = @import("std");
const base_uri = std.Uri.parse("http://api.brain-map.org/") catch unreachable;

const SpecimentListResponse = struct {
    success: bool,
    num_rows: u32,
    msg: []Specimen,
};

const Specimen = struct {
    id: u64,
    well_known_files: []WellKnownFile,
};

const WellKnownFile = struct {
    id: u64,
    path: []const u8,
};

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

// Retrieve list of specimens from the Allen API.
pub fn fetch_specimens() ![]Specimen {

}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "parse specimen list" {
    // const response =
    //     \\{
    //     \\  "success": true,
    //     \\  "num_rows": 50,
    //     \\  "msg: [
    //     \\    {
    //     \\      "id": 1234,
    //     \\      "well_known_files": [
    //     \\        {
    //     \\          "id": 5678,
    //     \\          "path": "/external/mousecelltypes/prod146/specimen_123/file.swc"
    //     \\        }
    //     \\      ]
    //     \\    }
    //     \\  ]"
    //     \\}
    // ;
}

// test "http" {
//     const allocator = std.testing.allocator;
//     var client: std.http.Client = .{ .allocator = allocator };
//     defer client.deinit();
//
//     var req = try client.request(.GET, uri, .{ .allocator = allocator }, .{});
//     defer req.deinit();
//     try req.start();
//     try req.wait();
//
//     try std.testing.expect(req.response.status == .ok);
// }
