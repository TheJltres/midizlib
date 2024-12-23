const std = @import("std");
const MidTypes = @import("../types.zig");
const MidEvent = MidTypes.MidEvent;
const MidReader = @import("../midz.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    if (!args.skip()) {
        return;
    }

    const file_name = args.next().?;
    std.debug.print("file to parse: {s}\n", .{file_name});

    const file = try std.fs.openFileAbsolute(file_name, .{ .mode = .read_only });
    defer file.close();

    const reader = MidReader.init(file.reader());
    // try readMid(reader);

    var tracks = std.ArrayList(MidTypes.MidTrack).init(allocator);
    defer tracks.deinit();

    var events = std.ArrayList(MidTypes.MidEvent).init(allocator);
    defer events.deinit();

    const midfile = try reader.readMidAlloc(allocator);
    defer midfile.deinit();

    try readMidAlloc(midfile);
}

fn readMid(reader: MidReader) !void {
    const header = try reader.readMidHeader();
    std.debug.print("Header:\n", .{});
    std.debug.print("\tLength: {d}\n", .{header.length});
    std.debug.print("\tFormat: {d}\n", .{@intFromEnum(header.format)});
    std.debug.print("\tNº tracks: {d}\n", .{header.ntracks});
    std.debug.print("\tTiming: {d}\n", .{header.tickdiv});
    std.debug.print("\n", .{});

    for (0..header.ntracks) |_| {
        const track_length = try reader.readMidTrackLength();
        std.debug.print("Track:\n", .{});
        std.debug.print("\tLength: {d}\n", .{track_length});

        while (true) {
            const event = try reader.readMidEvent();
            std.debug.print("\t\tEvent:", .{});
            std.debug.print("\t{d}\t{any}\n", .{ event.vtime, std.json.fmt(event.event, .{}) });

            switch (event.event) {
                .endOfTrack => break,
                else => continue,
            }
        }

        std.debug.print("\n", .{});
    }
}

fn readMidAlloc(mid: MidTypes.MidFile) !void {
    const header = mid.header;
    std.debug.print("Header:\n", .{});
    std.debug.print("\tLength: {d}\n", .{header.length});
    std.debug.print("\tFormat: {d}\n", .{@intFromEnum(header.format)});
    std.debug.print("\tNº tracks: {d}\n", .{header.ntracks});
    std.debug.print("\tTiming: {d}\n", .{header.tickdiv});
    std.debug.print("\n", .{});

    for (mid.tracks.items) |track| {
        std.debug.print("Track:\n", .{});
        std.debug.print("\tLength: {d}\n", .{track.length});

        for (track.events.items) |event| {
            std.debug.print("\t\tEvent:", .{});
            std.debug.print("\t{d}\t{any}\n", .{ event.vtime, std.json.fmt(event.event, .{}) });
        }

        std.debug.print("\n", .{});
    }
}
