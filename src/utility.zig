//!/*
//! * src/utility.zig
//! * Q@hackers.pk  
//! */

const std = @import("std");

pub const Utility = struct {
    /// Prints the help text of each command line option along with all aliases in a beautiful format.
    pub fn help(commands_str: []const u8) void {
        std.debug.print("\n", .{});
        std.debug.print("================================================================================\n", .{});
        std.debug.print("                           FeaturePick - Help Menu                              \n", .{});
        std.debug.print("================================================================================\n\n", .{});
        std.debug.print("  {s:<35} {s}\n", .{ "COMMAND ALIASES", "DESCRIPTION" });
        std.debug.print("  {s:<35} {s}\n", .{ "---------------", "-----------" });

        var line_iter = std.mem.splitScalar(u8, commands_str, '\n');
        while (line_iter.next()) |line| {
            if (line.len == 0) continue;
            
            const desc_start = std.mem.indexOfScalar(u8, line, '(');
            const desc_end = std.mem.lastIndexOfScalar(u8, line, ')');
            
            if (desc_start) |start| {
                if (desc_end) |end| {
                    const aliases_part = line[0..start];
                    const desc_part = line[start + 1 .. end];
                    
                    var clean_aliases = aliases_part;
                    // Remove trailing comma if present
                    if (clean_aliases.len > 0 and clean_aliases[clean_aliases.len - 1] == ',') {
                        clean_aliases = clean_aliases[0 .. clean_aliases.len - 1];
                    }
                    
                    std.debug.print("  {s:<35} {s}\n", .{ clean_aliases, desc_part });
                }
            }
        }
        std.debug.print("\n================================================================================\n\n", .{});
    }
};
