const std = @import("std");
const MidTypes = @import("./types.zig");

reader: std.fs.File.Reader,

pub fn init(reader: anytype) @This() {
    return @This(){
        .reader = reader,
    };
}

pub fn read(self: @This(), buffer: []u8) !usize {
    return try self.reader.read(buffer);
}

pub fn readByte(self: @This()) !u8 {
    return try self.readInt(u8);
}

pub fn readChunkFormat(self: @This()) !MidTypes.MidiChunkFormat {
    return try self.reader.readEnum(MidTypes.MidiChunkFormat, .big);
}

pub fn readInt(self: @This(), comptime T: type) !T {
    return try self.reader.readInt(T, .big);
}

pub fn readIntVariableLength(self: @This()) !u32 {
    const value: u8 = try self.reader.readByte();
    if (value >> 7 == 0) {
        return value;
    }

    return value + try self.readIntVariableLength();
}

pub fn readMidAlloc(self: @This(), allocator: std.mem.Allocator) !MidTypes.MidFile {
    const header = try self.readMidHeader();
    var file = try MidTypes.MidFile.init(header, allocator);
    for (0..header.ntracks) |_| {
        const track = try self.readMidTrackAlloc(allocator);
        try file.tracks.appendAssumeCapacity(track);
    }

    return file;
}

pub fn readMidHeader(self: @This()) !MidTypes.MidHeader {
    var buffer: [4]u8 = undefined;

    const identifier_size = try self.read(&buffer);
    if (buffer.len != identifier_size) {
        std.debug.print("Header is incomplete\n", .{});
        unreachable;
    } else if (!std.mem.eql(u8, &buffer, "MThd")) {
        std.debug.print("Header not valid\n", .{});
        unreachable;
    }

    const length = try self.readInt(u32);
    if (length != 6) {
        _ = try std.io.getStdOut().write("Header length is not the expected");
    }

    const format = try self.readChunkFormat();
    const ntracks = try self.readInt(u16);
    const tickdiv = try self.readInt(u16);

    return MidTypes.MidHeader{
        .length = length,
        .format = format,
        .ntracks = ntracks,
        .tickdiv = tickdiv,
    };
}

pub fn readMidTrackLength(self: @This()) !u32 {
    var buffer: [4]u8 = undefined;

    const identifier_size = try self.read(&buffer);
    if (buffer.len != identifier_size) {
        std.debug.print("Track is incomplete\n", .{});
        unreachable;
    } else if (!std.mem.eql(u8, &buffer, "MTrk")) {
        std.debug.print("Track not valid\n", .{});
        unreachable;
    }

    return try self.readInt(u32);
}

pub fn readMidTrackAlloc(self: @This(), allocator: std.mem.Allocator) !MidTypes.MidTrack {
    const length = try self.readMidTrackLength();
    var events = try MidTypes.MidTrack.init(length, allocator);

    while (true) {
        const event = try self.readMidEvent();
        try events.events.append(event);

        switch (event.event) {
            .endOfTrack => break,
            else => continue,
        }
    }

    return events;
}

pub fn readMidEvent(self: @This()) !MidTypes.MidEvent {
    const vtime = try self.readIntVariableLength();

    // TODO: Improve...
    const status = try self.readByte();
    const channel: u4 = @truncate(status << 4);

    const event = switch (status) {
        0x80...0xef => try self.parseEventMidi(@intCast(status >> 4), channel),
        0xf0...0xf7 => unreachable,
        0xff => try self.parseEventMeta(),
        else => MidTypes.MidEventUnion{ .unknown = status },
    };

    return MidTypes.MidEvent{
        .vtime = vtime,
        .event = event,
    };
}

fn parseEventMidi(self: @This(), event: u4, channel: u4) !MidTypes.MidEventUnion {
    switch (event) {
        0x8 => {
            const note = try self.readByte();
            const velocity = try self.readByte();

            return MidTypes.MidEventUnion{
                .noteOff = .{
                    .channel = channel,
                    .note = note,
                    .velocity = velocity,
                },
            };
        },
        0x9 => {
            const note = try self.readByte();
            const velocity = try self.readByte();

            return MidTypes.MidEventUnion{
                .noteOn = .{
                    .channel = channel,
                    .note = note,
                    .velocity = velocity,
                },
            };
        },
        0xa => {
            const note = try self.readByte();
            const pressure = try self.readByte();

            return MidTypes.MidEventUnion{
                .polyphonicPressure = .{
                    .channel = channel,
                    .note = note,
                    .pressure = pressure,
                },
            };
        },
        0xb => {
            const controller = try self.readByte();
            const value = try self.readByte();

            return MidTypes.MidEventUnion{
                .controller = .{
                    .channel = channel,
                    .controller = controller,
                    .value = value,
                },
            };
        },
        0xc => {
            const program = try self.readByte();

            return MidTypes.MidEventUnion{
                .programChange = .{
                    .channel = channel,
                    .program = program,
                },
            };
        },
        0xd => {
            const pressure = try self.readByte();

            return MidTypes.MidEventUnion{
                .channelPressure = .{
                    .channel = channel,
                    .pressure = pressure,
                },
            };
        },
        0xe => {
            const lsb = try self.readByte();
            const msb = try self.readByte();

            return MidTypes.MidEventUnion{
                .pitchBend = .{
                    .channel = channel,
                    .lsb = lsb,
                    .msb = msb,
                },
            };
        },
        else => {
            std.debug.print("Unknown midi event: {x}\n", .{event});
            return MidTypes.MidEventUnion{
                .unknown = event,
            };
        },
    }
}

fn parseEventMeta(self: @This()) !MidTypes.MidEventUnion {
    const status = try self.readByte();
    switch (status) {
        // 0x00 => {},
        // 0x01 => {},
        // 0x02 => {},
        // 0x03 => {},
        // 0x04 => {},
        // 0x05 => {},
        // 0x06 => {},
        // 0x07 => {},
        // 0x08 => {},
        // 0x09 => {},
        // 0x20 => {},
        // 0x21 => {},
        0x2f => {
            const eot = try self.readByte();
            if (eot != 0x00) unreachable;

            return MidTypes.MidEventUnion{
                .endOfTrack = .{},
            };
        },
        0x51 => {
            const expected = try self.readByte();
            if (expected != 0x03) unreachable;

            const ms = try self.readInt(u24);

            return MidTypes.MidEventUnion{
                .tempo = .{
                    .microseconds = ms,
                },
            };
        },
        // 0x54 => {},
        0x58 => {
            const expected = try self.readByte();
            if (expected != 0x04) unreachable;

            const numerator = try self.readByte();
            const denominator = try self.readByte();
            const clocks = try self.readByte();
            const notated = try self.readByte();

            return MidTypes.MidEventUnion{
                .timeSignature = .{
                    .numerator = numerator,
                    .denominator = denominator,
                    .clocks = clocks,
                    .notated = notated,
                },
            };
        },
        0x59 => {
            const expected = try self.readByte();
            if (expected != 0x02) unreachable;

            const sf = try self.readByte();
            const mi = try self.readByte();

            return MidTypes.MidEventUnion{
                .keySignature = .{
                    .flatsOrSharps = sf,
                    .majorOrMinor = mi,
                },
            };
        },
        else => {
            std.debug.print("Unknown meta status: {x}\n", .{status});
            return MidTypes.MidEventUnion{
                .unknown = status,
            };
        },
    }
}
