const std = @import("std");
const base_uri = std.Uri.parse("http://api.brain-map.org/") catch unreachable;
const api_uri = std.Uri.parse("http://api.brain-map.org/") catch unreachable;

pub fn PageOf(comptime T: type) type {
    return struct {
        success: bool,
        num_rows: u32,
        msg: []T
    };
}

const SpecimenId = struct { specimen__id: u64 };

const Specimen = struct {
    id: u64,
    well_known_files: []WellKnownFile,
};

const WellKnownFile = struct {
    id: u64,
    well_known_file_type: u64,
    path: []const u8,
};

// Retrieve list of specimens from the Allen API.
pub fn fetch_specimens(
    allocator: std.mem.Allocator,
    client: *std.http.Client
) !PageOf(SpecimenId) {

    const specimens_uri = std.Uri.parse("http://api.brain-map.org/api/v2/data/query.json?criteria=model::ApiCellTypesSpecimenDetail,rma::criteria,[nr__reconstruction_type$nenull]") catch unreachable;
    var req = try client.request(.GET, specimens_uri, .{ .allocator = allocator }, .{});
    try req.start();
    try req.wait();
    const body = try req.reader().readAllAlloc(allocator, 2000000);

    const specimens = try std.json.parseFromSlice(PageOf(SpecimenId), allocator, body, .{ .ignore_unknown_fields = true });

    return specimens;

}

pub fn fetch_specimen(
    allocator: std.mem.Allocator,
    client: *std.http.Client,
    specimen_id: u64
) !PageOf(Specimen) {
    const uri = try std.fmt.allocPrint(
        allocator,
        "{s}query.json?criteria=model::NeuronReconstruction,rma::criteria,[specimen_id$eq{}],rma::include,well_known_files",
        .{ api_uri, specimen_id }
    );
    const specimen_uri = std.Uri.parse(uri) catch unreachable;
    var req = try client.request(.GET, specimen_uri, .{ .allocator = allocator }, .{});
    try req.start();
    try req.wait();
    const body = try req.reader().readAllAlloc(allocator, 2000000);

    const specimen = try std.json.parseFromSlice(PageOf(Specimen), allocator, body, .{ .ignore_unknown_fields = true });
    return specimen;

}

pub fn main() !void {

    const allocator = std.heap.page_allocator;

    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const specimen_ids = try fetch_specimens(allocator, &client);
    std.debug.print("spicimen count: {}\n", .{specimen_ids.msg.len});
    for (specimen_ids.msg) |msg| {
        std.debug.print("specimen_id: {}\n", .{msg.specimen__id});
    }

    for (specimen_ids.msg) |msg| {
        const specimens = try fetch_specimen(allocator, &client, msg.specimen__id);
        for (specimens.msg) |s| {
            std.debug.print("id: {}\nn_files: {}\n\n", .{ s.id, s.well_known_files.len });
        }
        defer std.json.parseFree(PageOf(Specimen), allocator, specimens);
    }

    defer std.json.parseFree(PageOf(SpecimenId), allocator, specimen_ids);

}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "parse specimen list" {

    const allocator = std.testing.allocator;
    const response_json =
        \\{
        \\  "success": true,
        \\  "num_rows": 50,
        \\  "msg": [
        \\    {
        \\      "id": 1234,
        \\      "well_known_files": [
        \\        {
        \\          "id": 5678,
        \\          "path": "/external/mousecelltypes/prod146/specimen_123/file.swc"
        \\        }
        \\      ]
        \\    }
        \\  ]
        \\}
    ;
    const response = try std.json.parseFromSlice(PageOf(SpecimenId), allocator, response_json, .{});
    defer std.json.parseFree(PageOf(SpecimenId), allocator, response);

    try std.testing.expect(response.success == true);
    try std.testing.expect(response.num_rows == 50);
    try std.testing.expect(response.msg[0].id == 1234);
    try std.testing.expect(response.msg[0].well_known_files[0].path[0] == '/');
}

test "http" {
    const allocator : std.mem.Allocator = std.testing.allocator;
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const specimens_uri = std.Uri.parse("http://api.brain-map.org/api/v2/data/query.json?criteria=model::ApiCellTypesSpecimenDetail,rma::criteria,[nr__reconstruction_type$nenull]") catch unreachable;
    var req = try client.request(.GET, specimens_uri, .{ .allocator = allocator }, .{});
    defer req.deinit();
    try req.start();
    try req.wait();

    const body = try req.reader().readAllAlloc(allocator, 2000000);
    defer allocator.free(body);
    std.debug.print("body: {s}\n", .{body});

    try std.testing.expect(req.response.status == .ok);
}
