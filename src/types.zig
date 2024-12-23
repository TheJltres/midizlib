const std = @import("std");

pub const MidFile = struct {
    header: MidHeader,
    tracks: std.ArrayList(MidTrack),

    pub fn init(header: MidHeader, allocator: std.mem.Allocator) !MidFile {
        return MidFile{
            .header = header,
            .tracks = try std.ArrayList(MidTrack).initCapacity(allocator, header.ntracks),
        };
    }

    pub fn deinit(self: @This()) void {
        for (self.tracks.items) |track| {
            track.deinit();
        }

        self.tracks.deinit();
    }
};

pub const MidiChunkFormat = enum(u16) {
    single_track,
    multiple_track,
    multiple_song,
};

pub const MidHeader = struct {
    length: u32,
    format: MidiChunkFormat,
    ntracks: u16,
    tickdiv: u16,
};

pub const MidTrack = struct {
    length: u32,
    events: std.ArrayList(MidEvent),

    pub fn init(length: u32, allocator: std.mem.Allocator) !MidTrack {
        return MidTrack{
            .length = length,
            .events = std.ArrayList(MidEvent).init(allocator),
        };
    }

    pub fn deinit(self: @This()) void {
        self.events.deinit();
    }
};

pub const MidEvent = struct {
    vtime: u32,
    event: MidEventUnion,
};

pub const MidEventUnion = union(enum) {
    // MIDI events
    noteOff: MidiEventNoteOff,
    noteOn: MidiEventNoteOn,
    polyphonicPressure: MidiEventPolyphonicPressure,
    controller: MidiEventController,
    programChange: MidiEventProgramChange,
    channelPressure: MidiEventChannelPressure,
    pitchBend: MidiEventPitchBend,

    // SysEx events
    single: SysExEventSingle,
    escape: SysExEscape,

    // Meta events
    sequenceNumber: MetaEventSequenceNumber,
    text: MetaEventText,
    copyright: MetaEventCopyright,
    sequence: MetaEventSequence,
    instrumentName: MetaEventInstrumentName,
    lyric: MetaEventLyric,
    marker: MetaEventMarker,
    cuePoint: MetaEventCuePoint,
    programName: MetaEventProgramName,
    deviceName: MetaEventDeviceName,
    channelPrefix: MetaEventChannelPrefix,
    port: MetaEventPort,
    endOfTrack: MetaEventEndOfTrack,
    tempo: MetaEventTempo,
    SMPTEOffset: MetaEventSMPTEOffset,
    timeSignature: MetaEventTimeSignature,
    keySignature: MetaEventKeySignature,
    sequencerEspecificEvent: MetaEventSequencerEspecificEvent,

    unknown: u8,
};

// MIDI events
pub const MidiEventNoteOff = struct {
    channel: u4,
    note: u8,
    velocity: u8,
};

pub const MidiEventNoteOn = struct {
    channel: u4,
    note: u8,
    velocity: u8,
};

pub const MidiEventPolyphonicPressure = struct {
    channel: u4,
    note: u8,
    pressure: u8,
};

pub const MidiEventController = struct {
    channel: u4,
    controller: u8,
    value: u8,
};

pub const MidiEventProgramChange = struct {
    channel: u4,
    program: u8,
};

pub const MidiEventChannelPressure = struct {
    channel: u4,
    pressure: u8,
};

pub const MidiEventPitchBend = struct {
    channel: u4,
    lsb: u8,
    msb: u8,
};

// SysEx events
pub const SysExEventSingle = struct {
    length: u8,
    message: []u8,
};

pub const SysExEscape = struct {
    length: u8,
    bytes: []u8,
};

// Meta events
pub const MetaEventSequenceNumber = struct {
    message: u16,
};

pub const MetaEventText = struct {
    length: u8,
    text: []u8,
};

pub const MetaEventCopyright = struct {
    length: u8,
    text: []u8,
};

pub const MetaEventSequence = struct {
    length: u8,
    text: []u8,
};

pub const MetaEventInstrumentName = struct {
    length: u8,
    text: []u8,
};

pub const MetaEventLyric = struct {
    length: u8,
    text: []u8,
};

pub const MetaEventMarker = struct {
    length: u8,
    text: []u8,
};

pub const MetaEventCuePoint = struct {
    length: u8,
    text: []u8,
};

pub const MetaEventProgramName = struct {
    length: u8,
    text: []u8,
};

pub const MetaEventDeviceName = struct {
    length: u8,
    text: []u8,
};

pub const MetaEventChannelPrefix = struct {
    length: u8,
    text: []u8,
};

pub const MetaEventPort = struct {
    port: u8,
};

pub const MetaEventEndOfTrack = struct {};

pub const MetaEventTempo = struct {
    microseconds: u24,
};

pub const MetaEventSMPTEOffset = struct {
    hour: u8,
    minutes: u8,
    seconds: u8,
    frames: u8,
    fractional: u8,
};

pub const MetaEventTimeSignature = struct {
    numerator: u8,
    denominator: u8,
    clocks: u8,
    notated: u8,
};

pub const MetaEventKeySignature = struct {
    flatsOrSharps: u8,
    majorOrMinor: u8,
};

pub const MetaEventSequencerEspecificEvent = struct {
    length: u8,
    data: []u8,
};
