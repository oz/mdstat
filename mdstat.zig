// This file is part of mdstat.
//
// mdstat is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the
// Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// mdstat is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License
// along with mdstat.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const os = std.os;
const process = std.process;
const BufSet = std.BufSet;
const sort = std.sort;
const fmt = std.fmt;
const Kind = std.fs.Dir.Entry.Kind;

// MailDir uses "cur", "new", and "tmp" sub-folders. The "new" contains
// unread email messages.
const NewMailDir = "new/";
const DirSep = "/";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Get the MailDir path.
    if (os.argv.len < 2) return printHelp();
    var args = process.args();
    _ = args.skip();
    const root = try args.next(allocator) orelse {
        std.log.warn("Expected first argument to be a path\n", .{});
        return error.InvalidArgs;
    };

    var dirSet = findUnreadDirs(allocator, root) catch |err| {
        std.log.warn("Inspecting MailDir \"{s}\" failed: {}\n", .{ root, err });
        return error.Failure;
    };
    defer dirSet.deinit();

    var unreads = try explodeMailDirs(allocator, dirSet);
    defer unreads.deinit();
    return printSet(unreads);
}

fn printSet(set: BufSet) !void {
    const stdout = std.io.getStdOut().writer();

    var itr = set.iterator();
    while (itr.next()) |mb| {
        try stdout.print("{s} ", .{mb.*});
    }
    return stdout.print("\n", .{});
}

// Find directories that contains unread emails for a given MailDir
// path.
fn findUnreadDirs(allocator: std.mem.Allocator, path: []const u8) !BufSet {
    var dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var dirSet = BufSet.init(allocator);
    while (true) {
        var n = try walker.next();
        if (n == null) break;

        var entry = n.?;
        // Skip hidden nodes and look for files.
        if (entry.path[0] == '.' or entry.kind != Kind.File) continue;
        // We look for the "new" Maildir sub-folder indicating unread
        // messages are present.
        if (!std.mem.containsAtLeast(u8, entry.path, 1, NewMailDir)) continue;

        // Append the path up to "/{NewMailDir}" to a set.
        const i = std.mem.indexOf(u8, entry.path, NewMailDir).?;
        try dirSet.insert(entry.path[0 .. i - 1]);
    }
    return dirSet;
}

// Given a set of directories, build a list of MailDir names. MailDir
// are exploded so that "a/b/c" yields {"=a", "=a/b", "=a/b/c"}.
fn explodeMailDirs(allocator: std.mem.Allocator, unreadDirs: BufSet) !BufSet {
    var unreads = BufSet.init(allocator);
    var itr = unreadDirs.iterator();

    while (itr.next()) |dir| {
        var parts = std.mem.split(u8, dir.*, DirSep);
        var buf: [256]u8 = undefined;
        var acc = buf[0..];
        var i: usize = 0;
        while (parts.next()) |part| {
            if (i + part.len >= 256) return error.Overflow;

            if (i == 0) {
                std.mem.copy(u8, acc[0..], "=");
                std.mem.copy(u8, acc[1..], part);
                i += part.len + 1;
                try unreads.insert(acc[0..i]);
                continue;
            }
            std.mem.copy(u8, acc[i..], "/");
            i += 1;
            std.mem.copy(u8, acc[i..], part);
            i += part.len;
            try unreads.insert(acc[0..i]);
        }
    }
    return unreads;
}

fn printHelp() !void {
    const stdout = std.io.getStdOut().writer();
    const usage =
        \\ Usage: mdstat <maildir path> [options...]
        \\
    ;

    try stdout.print("{s}\n", .{usage});
    return os.exit(1);
}
