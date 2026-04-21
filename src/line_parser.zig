//!/*
//! * src/line_parser.zig
//! * Q@hackers.pk  
//! */

const std = @import("std");

pub const ParseError = error{
    OutOfMemory,
};

/// Configuration options for the `parse` method.
///
/// This struct allows the caller to customize how the line is parsed.
/// Since all fields have default values, you can pass an empty struct `.{}` 
/// to use the standard behavior.
pub const ParseOptions = struct {
    header: bool = false, // True if file has a header row (first row) 
    replaceWhiteSpacesWith: u8 = ' ', // Replace white space with symbol. Default is space. 
    
    // Optional list of line numbers to skip (e.g. 1, 4, 5, 6...). 
    // Checked in the code below.
    skip_lines: ?[]const usize = null, // Each list entry is checked against 'line_no'
    
    // The current line number being parsed (needed to check if we should skip)
    // We still strictly need `line_no` supplied to the parser! If we don't know the current line number, we have mathematically no way to compare against the `skip_lines` list
    line_no: usize = 0,
};

pub const LineParser = struct {
    // State fields
    text: []const u8, // The text to be parsed
    delimiter: u8, // The delimiter used to split the text into tokens
    allocator: std.mem.Allocator, // The allocator used to allocate memory
    /// List of parsed tokens.
    ///
    /// `std.ArrayListUnmanaged` is used here instead of `std.ArrayList` to avoid storing the
    /// allocator twice. Since `LineParser` already holds an `allocator` field, we can pass
    /// it explicitly to `ArrayListUnmanaged` methods (like `.append` or `.deinit`) rather
    /// than having every list carry its own allocator pointer.
    ///
    /// This reduces the memory footprint of the struct and is idiomatic Zig when the
    /// allocator is available in the context.
    tokens: std.ArrayListUnmanaged([]const u8),

    pub fn init(allocator: std.mem.Allocator, text: []const u8, delimiter: u8) LineParser {
        return LineParser{
            .text = text,
            .delimiter = delimiter,
            .allocator = allocator,
            .tokens = .{},
        };
    }

    pub fn deinit(self: *LineParser) void {
        self.tokens.deinit(self.allocator);
    }

    pub fn parse(self: *LineParser, options: ParseOptions) ParseError!void {
        
        var concatenatedTokens: []u8 = self.allocator.alloc(u8, 0) catch return ParseError.OutOfMemory;
        var oldLen: usize = 0;

        var quotationMarkFlag: bool = false;

        // If the optional skip_lines list is present, check if we should skip
        if (options.skip_lines) |lines| {
            for (lines) |skip_line| {
                if (options.line_no == skip_line) {
                    return; // Skip parsing entirely for this line
                }
            }
        }

        // It is still empty becuase I still don't know what to do in here
        if (options.header) {}

        // Iterate over tokens using the delimiter
        var it = std.mem.splitScalar(u8, self.text, self.delimiter);
        
        while (it.next()) |token| {

            //var concatenatedTokens: []u8 = self.allocator.alloc(u8, 0) catch return ParseError.OutOfMemory;
            
                //var concatenatedTokens = std.ArrayList(u8).init(self.allocator);
                //defer concatenatedTokens.deinit();

            if (token.len == 0) {

               std.debug.print("YES YES YES YES YES YES YES\n", .{}); 

               continue;
            }   

            // 1. Trim Token Spaces
            // --------------------
            // Trim leading and trailing spaces from the token (returns a slice view, no allocation)
            const trimmed_token: []const u8 = std.mem.trim(u8, token, " ");

            // 2. Allocate Token Memory
            // ------------------------
            // Allocate memory for the final token. Token is trimed its outer spaces and later its inner spaces will be (optionally) replaced with a symbol
            var trimmed_replaced_token: []u8 = self.allocator.alloc(u8, trimmed_token.len) catch return ParseError.OutOfMemory;
            
            // 3. Symbol Replacement
            // ---------------------
            // Perform (optional) replacement of white spaces with a symbol into the allocated memory
            const replacement: [1]u8 = [1]u8{options.replaceWhiteSpacesWith};
            _ = std.mem.replace(u8, trimmed_token, " ", &replacement, trimmed_replaced_token);

            // Between these stages 4. to 6., all tokens get concatenated into one token with white space being used as a separator

            // 4. Check Leading Quotes
            // -----------------------
            // Check for leading '\"' mark
            if (trimmed_replaced_token[0] == '\"') {                
                quotationMarkFlag = true;
                trimmed_replaced_token = trimmed_replaced_token[1..];

                oldLen = concatenatedTokens.len;
                concatenatedTokens = try self.allocator.realloc(concatenatedTokens, oldLen + trimmed_replaced_token.len);
                @memcpy(concatenatedTokens[oldLen..], trimmed_replaced_token);
                                
                //concatenatedTokens = std.mem.concat(self.allocator, u8, &[_][]const u8{concatenatedTokens, trimmed_replaced_token}) catch return ParseError.OutOfMemory;
            }  
            // 5. Check Trailing Quotes
            // ------------------------
            // Check for trailing '\"' mark
            else if (quotationMarkFlag and trimmed_replaced_token[trimmed_replaced_token.len - 1] == '\"') {
                quotationMarkFlag = false;
                trimmed_replaced_token = trimmed_replaced_token[0..(trimmed_replaced_token.len - 1)];

                // Add single space before the concatenation
                //concatenatedTokens = std.mem.concat(self.allocator, u8, &[_][]const u8{concatenatedTokens, " "}) catch return ParseError.OutOfMemory;

                oldLen = concatenatedTokens.len;
                concatenatedTokens = try self.allocator.realloc(concatenatedTokens, oldLen + 1);
                @memcpy(concatenatedTokens[oldLen..], " ");
                
                //concatenatedTokens = std.mem.concat(self.allocator, u8, &[_][]const u8{concatenatedTokens, trimmed_replaced_token}) catch return ParseError.OutOfMemory;

                oldLen = concatenatedTokens.len;
                concatenatedTokens = try self.allocator.realloc(concatenatedTokens, oldLen + trimmed_replaced_token.len);
                @memcpy(concatenatedTokens[oldLen..], trimmed_replaced_token);
                
                // Store the token in our list.
                self.tokens.append(self.allocator, concatenatedTokens) catch {
                    return ParseError.OutOfMemory;
                };
            } 
            // 6. Handle Intermediate Quoted Tokens
            // ------------------------------------
            else if (quotationMarkFlag) {

                // Add single space before the concatenation
                // concatenatedTokens = std.mem.concat(self.allocator, u8, &[_][]const u8{concatenatedTokens, " "}) catch return ParseError.OutOfMemory;

                oldLen = concatenatedTokens.len;
                concatenatedTokens = try self.allocator.realloc(concatenatedTokens, oldLen + 1);
                @memcpy(concatenatedTokens[oldLen..], " ");
                
                //concatenatedTokens = std.mem.concat(self.allocator, u8, &[_][]const u8{concatenatedTokens, trimmed_replaced_token}) catch return ParseError.OutOfMemory;

                oldLen = concatenatedTokens.len;
                concatenatedTokens = try self.allocator.realloc(concatenatedTokens, oldLen + trimmed_replaced_token.len);
                @memcpy(concatenatedTokens[oldLen..], trimmed_replaced_token);
                
            } else {

                // Store the token in our list.
                self.tokens.append(self.allocator, trimmed_replaced_token) catch {
                    return ParseError.OutOfMemory;
                };
            }
            
            // Visualize
            //std.debug.print("   -> Stored Token: \"{s}\" (Count: {d})\n", .{token, self.tokens.items.len});
        }
    }
};