const std = @import("std");
const api_uri = "http://api.brain-map.org/api/v2/data/";

pub fn PageOf(comptime T: type) type {
    return struct {
        success: bool,
        num_rows: u32,
        msg: []T
    };
}

const SpecimenId = struct { specimen__id: u64 };

const Reconstruction = struct {
    id: u64,
    well_known_files: []WellKnownFile,
};

const WellKnownFile = struct {
    id: u64,
    well_known_file_type_id: u64,
    path: []const u8,
    download_link: []const u8,
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

/// Fetch reconstructions for specimen id.
pub fn fetch_reconstructions(
    allocator: std.mem.Allocator,
    client: *std.http.Client,
    specimen_id: u64
) !PageOf(Reconstruction) {

    std.debug.print("Working on specimen {}\n", .{specimen_id});

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

    const reconstructions = std.json.parseFromSlice(PageOf(Reconstruction), allocator, body, .{ .ignore_unknown_fields = true });
    std.debug.print("Fetched reconstructions for specimen {}", .{specimen_id});
    return reconstructions;

}

// For the given reconstructions, find the first that has a well-known-file
// with our desired type. Create a file for the neuron, and return the file's path.
//  - The neuron file is determined by calling reuron-io's convert_swc endpoint.
pub fn handle_reconstructions(
    allocator: std.mem.Allocator,
    // client: *std.http.Client,
    specimen_id: u64,
    reconstructions: PageOf(Reconstruction)
) ![]const u8 {

    const base_uri = "http://api.brain-map.org";

    const target_type : u64 = 303941301;
    var download_link: []const u8 = "";
    var found_file = false;
    var reconstruction_id: u64 = 0;
    for (reconstructions.msg) |reconstruction| blk: {
        for (reconstruction.well_known_files) |well_known_file| {
            if (well_known_file.well_known_file_type_id == target_type) {
                found_file = true;
                download_link = well_known_file.download_link;
                reconstruction_id = reconstruction.id;
                break :blk;
            }
        }
    }

    if (!found_file) {
        return "";
    }

    const swc_remote_path = try std.fmt.allocPrint(
        allocator,
        "{s}{s}",
        .{base_uri, download_link}
    );

    const ffg_path = try std.fmt.allocPrint(
        allocator,
        "./neurons/{}_{}.ffg",
        .{specimen_id, reconstruction_id}
    );

    std.debug.print("Path hit: {s}\n", .{swc_remote_path});
    std.debug.print("ffg path: {s}\n", .{ffg_path});

    return download_link;
}


pub fn main() !void {

    const allocator = std.heap.page_allocator;

    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const specimen_ids = try fetch_specimens(allocator, &client);
    std.debug.print("spicimen count: {}\n", .{specimen_ids.msg.len});

    for (specimen_ids.msg) |msg| {
        if (fetch_reconstructions(allocator, &client, msg.specimen__id)) |reconstructions| {
            for (reconstructions.msg) |r| {
                std.debug.print("id: {}\nn_files: {}\n\n", .{ r.id, r.well_known_files.len });
            }
            const file = try handle_reconstructions(allocator, msg.specimen__id, reconstructions);

            std.debug.print("handle_reconstruction result: {s}", .{file});

            defer std.json.parseFree(PageOf(Reconstruction), allocator, reconstructions);
        } else |err| {
            std.debug.print("ERROR: {}\n", .{err});
        }
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
