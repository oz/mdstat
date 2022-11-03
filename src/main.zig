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
const accord = @import("./vendor/accord/accord.zig");

const os = std.os;
const process = std.process;
const BufSet = std.BufSet;
const sort = std.sort;
const fmt = std.fmt;
const Kind = std.fs.File.Kind;

// MailDir uses "cur", "new", and "tmp" sub-folders. The "new" contains
// unread email messages.
const NewMailDir = "new/";
const LiveMailDirSuffix = "/cur";
const DirSep = "/";
const MaxMaildirLen = 256;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parsing command-line flags with "accord".
    var args_iterator = std.process.args();
    const options = try accord.parse(&.{
        accord.option('u', "", accord.Flag, {}, .{}), // -u
        accord.option('h', "help", accord.Flag, {}, .{}), // -h or --help
    }, allocator, &args_iterator);
    defer options.positionals.deinit(allocator);

    if (options.help or options.positionals.items.len < 2) return printHelp();
    const root = options.positionals.items[1];

    // Find Maildirs...
    var finder_func = if (options.u) &findUnreadDirs else &findMailDirs;
    var set = finder_func(allocator, root) catch |err| {
        std.log.warn("Inspecting MailDir \"{s}\" failed: {}\n", .{ root, err });
        return error.Failure;
    };
    defer set.deinit();

    // Explode the MailDir tree if we're showing only unreads. This is
    // to make the maildir tree in neomutt's sidebar prettier.
    if (options.u) {
        var exploded = try explodeMailDirs(allocator, set);
        defer exploded.deinit();
        return printMailDirs(exploded);
    }
    return printMailDirs(set);
}

// Print a set of MailDirs to stdout.
fn printMailDirs(set: BufSet) !void {
    const stdout = std.io.getStdOut().writer();
    var itr = set.iterator();

    while (itr.next()) |md| {
        try stdout.print("=\"{s}\" ", .{md.*});
    }
    return stdout.print("\n", .{});
}

// Find directories that looks like maildirs under a given path.
fn findMailDirs(allocator: std.mem.Allocator, path: []const u8) !BufSet {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    var set = BufSet.init(allocator);

    while (true) {
        var n = try walker.next();
        if (n == null) break;

        var entry = n.?;
        // Skip hidden nodes and look for directories.
        if (entry.path[0] == '.' or entry.kind != Kind.Directory) continue;

        // We look for folders where the last sub-folder name ends with
        // "/cur" suffix, to decide it's a MailDir.
        if (!std.mem.endsWith(u8, entry.path, LiveMailDirSuffix)) continue;

        // Append the path up to LiveMailDirSuffix to a set.
        const i = std.mem.indexOf(u8, entry.path, LiveMailDirSuffix).?;
        try set.insert(entry.path[0..i]);
    }
    return set;
}

// Find directories that contains unread emails for a given MailDir
// path.
fn findUnreadDirs(allocator: std.mem.Allocator, path: []const u8) !BufSet {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    var set = BufSet.init(allocator);

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
        try set.insert(entry.path[0 .. i - 1]);
    }
    return set;
}

// Given a set of directory names, build a new set containing each level
// of the directory tree, once: "a/b/c" yields {"a", "a/b", "/b/c"}.
fn explodeMailDirs(allocator: std.mem.Allocator, dir_set: BufSet) !BufSet {
    var exploded = BufSet.init(allocator);
    var itr = dir_set.iterator();

    // XXX 256 characters are enough for most people, right? :D
    var buf: [MaxMaildirLen]u8 = undefined;
    var acc = buf[0..];

    while (itr.next()) |dir| {
        var parts = std.mem.split(u8, dir.*, DirSep);
        var i: usize = 0;
        while (parts.next()) |part| {
            if (i + part.len >= MaxMaildirLen) return error.Overflow;
            if (i != 0) {
                std.mem.copy(u8, acc[i..], "/");
                i += 1;
            }
            std.mem.copy(u8, acc[i..], part);
            i += part.len;
            try exploded.insert(acc[0..i]);
        }
    }
    return exploded;
}

fn printHelp() !void {
    const stdout = std.io.getStdOut().writer();
    const usage =
        \\Usage: mdstat <maildir path> [options...]
        \\    -u   list unread only, with all intermediate folders
        \\    -h   shows this
        \\
    ;

    try stdout.print("{s}\n", .{usage});
    return os.exit(1);
}
