//!/*
//! * src/main.zig
//! * Q@hackers.pk  
//! */

// https://pedropark99.github.io/zig-book/Chapters/12-file-op.html

const std = @import("std");
const Argsv = @import("argsv");
const LineParser = @import("line_parser.zig").LineParser;
const ParseError = @import("line_parser.zig").ParseError;
const Utility = @import("utility.zig").Utility;

const commands = "h,-h,help,(Display this help message)\n" ++
                 "v,-v,verbose,(Enable verbose output logging)\n" ++
                 "fi,-fi,input-file,(Path to the input file to read)\n" ++
                 "fo,-fo,output-file,(Path to the output file to write)\n" ++
                 "c,-c,column,(The 0-based index of the column to extract)\n" ++
                 "r,-r,replace,(Replace whitespace with the specified character)\n" ++
                 "remove-header,(Remove the header or first line from the input)";

// !void: Returns nothing on success, but can return an error.
// You can also explicitly state the error set. For example, MyError!void means the function can only return errors defined in MyError or a void value.
// In the absence of explicit MyError, the compiler will infer the error set based on the return statements in the function.
// This is the standard pattern of "return type signature" for the application entry point.
pub fn main() !void {

    // Boiler plate code

    // 1. Setup Allocator
    // ------------------
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var arenaAllocator = arena.allocator();

    // 2. Get ARGV / ARGC Equivalent
    // -----------------------------
    // argsAlloc returns a slice ([][]const u8)
    const args = try std.process.argsAlloc(arenaAllocator);
    // Note: Since we use Arena, we don't strictly need argsFree, 
    // but it's good practice.
    defer std.process.argsFree(arenaAllocator, args);

    //const argc = args.len;     // argc equivalent
    const argv = args;         // argv equivalent (can access as argv[0], etc.)

    // 3. Instantiate Command Line Processor
    // -------------------------------------
    var argsv = Argsv.Argsv.new(&arenaAllocator);   

    argsv.build(commands) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidCmdLine => return error.InvalidCmdLine,
    };

    var argsvForInputFile = argsv.find(commands, "-fi"); 
    var argsvForOutputFile = argsv.find(commands, "-fo");
    var argsvForVerbose = argsv.find(commands, "verbose");
    var argsvForColumn = argsv.find(commands, "-c");
    var argsvForReplace = argsv.find(commands, "replace");
    var argsvForRemoveHeader = argsv.find(commands, "remove-header");
    var argsvForHelp = argsv.find(commands, "help");

    if (args.len == 1 or argsvForHelp.index() != 0) {
        Utility.help(commands);
        return;
    }

    var iFName: []const u8 = ""; // Input file name
    var oFName: []const u8 = ""; // Output file name

    // If replace option is used, replace white space with the symbol given as the argument to this option
    var whiteSpaceReplacement: u8 = '-';    
    if (argsvForReplace.index() != 0) {
        whiteSpaceReplacement = argv[argsvForReplace.index() + 1][0];
    }

    if (argsvForInputFile.index() != 0) {
        if (argsvForInputFile.n() > 1) {
            iFName = argv[argsvForInputFile.index() + 1];
        } else {
            std.debug.print("{s}\n", .{argsvForInputFile.help(commands)});            
            return;
        }
    } else {
        //std.debug.print("Usage: This program expects, a input file name. Please take \"help\".\n", .{});
        //return;
    }
    
    if (argsvForOutputFile.index() != 0) {
       if (argsvForOutputFile.n() > 1) {
           oFName = argv[argsvForOutputFile.index() + 1];
       } else {
           std.debug.print("{s}\n", .{argsvForOutputFile.help(commands)});
           return;
       }
    } else {

        //std.debug.print("Usage: This program expects, a output file name. Please take \"help\".\n", .{});
        //return;
    }

    if (iFName.len == 0 or oFName.len == 0) {
        std.debug.print("Usage: This program expects, input and output file names. Please take \"help\".\n", .{});        
        return;
    }

    // JUST READ FILE LINE BY LINE

    const ifile = std.fs.cwd().openFile(iFName, .{.mode = .read_only}) catch |err| switch (err) {       
        error.FileNotFound => {
            std.debug.print("Error: The file '{s}' was not found.\n", .{iFName});
            return;
        },
        error.AccessDenied => {
            std.debug.print("Error: Permission denied for '{s}'.\n", .{iFName});
            return;
        },
        error.IsDir => {
            std.debug.print("Error: '{s}' is a directory, not a file.\n", .{iFName});
            return;
        },
        else => {
            // Catch-all for rare errors like PathTooLong or SystemResources
            std.debug.print("Unexpected error opening file: {}\n", .{err});
            return;
        },
    };
    defer ifile.close();

    // Create file if it doesn't exist, overwrite if it does. 
    const ofile = std.fs.cwd().createFile(oFName, .{}) catch |err| switch (err) {
        error.AccessDenied => {
            std.debug.print("Error: Permission denied for '{s}'.\n", .{oFName});
            return;
        },
        error.IsDir => {
            std.debug.print("Error: '{s}' is a directory, not a file.\n", .{oFName});
            return;
        },
        else => {
            std.debug.print("Unexpected error creating file: {}\n", .{err});
            return;
        },
    };
    defer ofile.close();

    // /// A QUICK DESCRIPTION
    // /// The writer and reader pattern.

    // /// Every IO operation in Zig is made through either a Reader or a Writer object. 
    // /// These two data types are actually interfaces, and they come from the std.Io module of the Zig Standard Library.
    // /// - Reader is an object that offers tools to read data from “something” (or “somewhere”), 
    // /// - Writer is an object that offers tools to write data to “something”.
    // /// -- This “something” might be different things: like a file that exists in your filesystem; or, 
    // /// -- it might be a network socket in your computer’s network interface; or, 
    // /// -- it might be a pipe in your computer’s memory, a continuous stream of data, like a standard input device from your system.
    // /// 
    // /// 1. If you want to read data from something, or somewhere, it means that you need to use a Reader object.
    // /// 2. If you need to write data into this “something”, then, you need to use a Writer object.
    // /// Both of these objects are normally created from a file descriptor object. More specifically,
    // /// through the writer() and reader() methods of this file descriptor object.
    // /// 
    // /// Writer object: Small Description
    // /// --------------------------------
    // /// Every Writer object has methods like print(), which allows you to write/send a formatted string (i.e.,
    // /// this formatted string is like a f string in Python, or,
    // /// similar to the printf() C function) into the “something” (file, socket, stream, etc.) that you are using.
    // /// It also has a writeAll() method, which allows you to write a string, or, an array of bytes into the “something”.
    // /// 
    // /// Reader object: Small Description
    // /// --------------------------------
    // /// Every Reader object have methods like readSliceAll(),
    // /// which allows you to read data from the “something” (file, socket, stream, etc.) until it fills a particular array (i.e.a “buffer”) object.
    // /// In other words,
    // /// if you provide an array object of 300 u8 values to readSliceAll(),
    // /// then, this method attempts to read 300 bytes of data from the “something”, and it stores them into the array object that you have provided.
    // /// Another useful method is take Delimiter Exclusive(). In this method, you specify a “delimiter character”.
    // /// This function will attempt to read as many bytes of data as possible from the “something” until it finds the “delimiter character” that you have specified,
    // /// and, it returns a slice with the data to you.
    // /// 
    // /// 
    // ///

    // You usually start your Zig code by choosing both an allocator, and also, an “IO backend implementation” to use. 
    // If you don’t care much, and just want to quickly get an “IO backend implementation” for your code to use, you can either: 
    // 1) use std.testing.io, which, as the name suggests, it is more tailored for unit tests (const io = std.testing.io; var file_reader = file.reader(io, &buffer);); or 
    // 2) use .init_single_threaded to quickly instantiate a std.Io.Threaded object using a single thread (var threaded = std.Io.Threaded.init_single_threaded;).
    
    // Single-threaded IO backend (lightweight, no extra threads, no allocator needed)
    var threaded = std.Io.Threaded.init_single_threaded;
    // The “IO backend implementation” that you want to use while reading the file.    
    const io_backend: std.Io = threaded.io();

    // Buffer – 8KB is great for typical text lines
    var read_buffer: [8192]u8 = undefined; // Separate buffer for reading

    // 1. Setup Write Buffer
    // ---------------------
    var write_buffer: [8192]u8 = undefined; // Separate buffer for writing

    // Since Zig 0.16, you will find different functions across the Zig Standard Library that takes an argument named io of type std.Io.
    // A big example of that is the reader() method that you find in std.fs.File.
    // This method is responsible for creating the Reader object through which you can read data from the file represented by the std.fs.File object.
    // And this method have now, an io argument, in which you should provide the “IO backend implementation” that you want to use while reading the file.
    var file_reader = ifile.reader(io_backend, &read_buffer);

    // 2. Initialize File Writer
    // -------------------------
    var file_writer = ofile.writer(&write_buffer);

    // Every IO operation in Zig is made through either a Reader or a Writer object.
    // These two data types are actually interfaces, and they come from the std.Io module of the Zig Standard Library.
    // Reader is an object that offers tools to read data from “something” (or “somewhere”)
    var reader = &file_reader.interface; // Get pointer to the interface

    // 3. Get Writer Interface Pointer
    // -------------------------------
    var writer = &file_writer.interface; // Get pointer to the interface

    var line_no: usize = 1; // 

    while (reader.takeDelimiter('\n')) |raw_line_opt| {
        
        // raw_line_opt is ?[]u8. Unwrap the optional part for when EOF is reached. When EOF then come out of the loop.
        const raw_line = raw_line_opt orelse break; // break on EOF (null)
    
        // raw_line is the text without any trailing '\n'. If your are on Windows then '\r' is still there.

        // Trim trailing '\r' for Windows files (optional)
        const line: []const u8 = std.mem.trim(u8, raw_line, "\r");
    
        // === LINE PROCESSING GOES HERE ===

        if (argsvForVerbose.index() != 0) {
            std.debug.print("[{d:0>5}] {s}\n", .{ line_no, line });
        }

        // Initialize parser with allocator, text, and delimiter
        // We use the arenaAllocator so all memory is freed at the end of the program anyway,
        // but it's good practice to call deinit() for struct cleanup logic.
        var lineParser = LineParser.init(arenaAllocator, line, ',');
        defer lineParser.deinit();
        
        // LEARNING NOTE: Explicit Error Handling vs 'try'
        // Since main() has the signature !void (inferring the error set), we could simply use:
        //     try lineParser.parse();
        // and the 'try' keyword would automatically propagate any error to the caller.
        // However, we are explicitly catching the error here for documentation/learning purposes
        // to show how we *could* handle specific errors if main() had a restricted signature.
        var skip_list: []const usize = &[_]usize{};
        if (argsvForRemoveHeader.index() != 0) {
            skip_list = &[_]usize{1};
        }
        
        lineParser.parse(.{
            .header = true, 
            .replaceWhiteSpacesWith = whiteSpaceReplacement,
            .skip_lines = if (skip_list.len > 0) skip_list else null,
            .line_no = line_no,
        }) catch |err| {            
            if (err == ParseError.OutOfMemory) {

                std.debug.print("main() Error: Out of memory\n", .{});
                return ParseError.OutOfMemory;
            } else {
                //std.debug.print("main() Error: {s}\n", .{err});
                return err;
            }

            //error.ParseError => return error.ParseError;
            //std.debug.print("Error: {s}\n", .{err});
            //{
            //    std.debug.print("Error: Out of memory\n", .{});
            //    return err;
            //};            
        };

        var column: []const u8 = "";        
        if (argsvForColumn.index() != 0) {
            if (argsvForColumn.n() > 1) {

                column = argv[argsvForColumn.index() + 1];

                std.debug.print("Column: {s}\n", .{column});
            } else {
                //std.debug.print("Usage: This program expects, a column number. Please take \"help\".\n", .{});
                std.debug.print("{s}\n", .{argsvForColumn.help(commands)});
                return;
            }
        } else {
            std.debug.print("Usage: This program expects, a column number. Please take \"help\".\n", .{});
            return;
        }
        // In Zig, you don't "cast" a string to a number; you parse it.
        // Since the input string might not be a valid number (e.g., "abc"),
        // parsing can fail, so it returns an error union.
        const col_index = std.fmt.parseInt(usize, column, 10) catch |err| {
            std.debug.print("Error parsing column number '{s}': {}\n", .{column, err});
            return;
        };

        // Accessing the parsed tokens in the main loop
        //std.debug.print("Tokens: {d}\n", .{lineParser.tokens.items.len});
        //for (lineParser.tokens.items) |token| {
            //std.debug.print("  Parsed: {s}\n", .{token});
        //}

        if (column.len > 0 and col_index < lineParser.tokens.items.len and argsvForVerbose.index() != 0) {
            //std.debug.print("Column: {s}\n", .{column}); 

            std.debug.print("Column: {s}\n", .{lineParser.tokens.items[col_index]});
        }

        // Concatenate tokens together separated by a white space
        //const joined = try std.mem.join(arenaAllocator, " ", lineParser.tokens.items);
        //std.debug.print("  Joined: {s}\n", .{joined});

        // 4. Keeping Bounds Protection
        // ----------------------------
        // Re-apply the bounds protection block prior to writing output.
        // Without this bound checker, reading a token on the lines purposefully skipped over using `-remove-header`
        // will instantly execute an array out-of-bounds Panic because `tokens` list wasn't populated from taking the `return;` early exit! 
        //try writer.writeAll(line);
        if (col_index < lineParser.tokens.items.len) {
            // Write the specifically requested column token from the current parsed row into our output buffer
            try writer.writeAll(lineParser.tokens.items[col_index]); 
            
            // Append a newline character so each extracted item stacks vertically, forming a single column in the output file
            try writer.writeAll("\n"); 
        }
    
        // Increment the tracker for the *next* iteration.
        // Because `line_no` originated at `1` and is incremented here at the very end of each cycle,
        // it pushes the counter one digit ahead of the actual total handled lines.
        // (This is why we must subtract 1 in our final print statements at the bottom of the script!)
        line_no += 1;
    } else |err| switch (err) {
        error.StreamTooLong => {
            std.debug.print("Error: Line too long (>8KB) – increase buffer size!\n", .{});
            return err;
        },
        else => return err, // Unexpected read error
    }

    // 5. Flush Remaining Output
    // -------------------------
    try writer.flush();

    std.debug.print("\n=== Finished ===\n", .{});
    // We subtract `- 1` because `line_no` starts initialized at `1` (not `0`),
    // and correctly gets incremented (+1) at the VERY END of each while loop cycle.
    // So if exactly 10 lines were read, `line_no` will be 11 upon loop exit!
    std.debug.print("Processed {} lines from '{s}'\n", .{ line_no - 1, iFName }); 
    std.debug.print("Saved {} lines to '{s}'\n", .{ line_no - 1, oFName });

    return;
} 