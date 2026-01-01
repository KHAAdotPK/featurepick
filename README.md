# FeaturePick

**FeaturePick** is a high-performance command-line tool written in Zig for extracting specific columns from large delimited text files (like CSVs). It is specifically designed to facilitate data preparation for Machine Learning models by quickly isolating relevant features from massive datasets.

## Features

- **Fast & Memory Efficient**: Built with Zig, utilizing an `ArenaAllocator` for optimal performance with large files.
- **Quote-Aware Parsing**: Correctly handles fields enclosed in double quotes (`"`), even when they contain delimiters.
- **Customizable Extraction**: Easily pick columns by their 0-based index.
- **White-Space Management**: Optionally replace spaces within tokens to ensure data consistency for ML pipelines.
- **Verbose Logging**: Detailed output mode to track processing step-by-step.

## Dependencies

- **[argsv-zig](https://github.com/KHAAdotPK/argsv-zig)**: A powerful command-line argument processor for Zig (under development).

## Installation

### Prerequisites

- [Zig](https://ziglang.org/download/) (version 0.16.0 or later recommended).

### Building from Source

1. Clone the **FeaturePick** repository.
2. Clone the **argsv-zig** dependency into the `lib` folder:
   ```bash
   mkdir -p lib
   git clone https://github.com/KHAAdotPK/argsv-zig lib/argsv-zig
   ```
3. Build the project using the Zig build system:

```bash
zig build -Doptimize=ReleaseSafe
```

The executable will be located in `zig-out/bin/featurepick` (or `featurepick.exe` on Windows).

## Usage

```bash
featurepick -fi <input_file> -fo <output_file> -c <column_index> [options]
```

### Options

| Option | Alias | Description |
| :--- | :--- | :--- |
| `h` | `-h`, `help` | Display the help message. |
| `v` | `-v`, `verbose` | Enable verbose output logging. |
| `fi` | `-fi`, `input-file` | Path to the input file to read. |
| `fo` | `-fo`, `output-file` | Path to the output file to write. |
| `c` | `-c`, `column` | 0-based index of the column to extract. |

### Example

To extract the second column (index `1`) from a file named `dataset.csv` and save it to `targets.txt`:

```bash
featurepick -fi dataset.csv -fo targets.txt -c 1
```

## How it Works

FeaturePick uses a custom `LineParser` that:
1. Splits lines by a delimiter (defaulting to `,` in the current implementation).
2. Trims leading and trailing spaces from each token.
3. Automatically concatenates tokens that are split by delimiters but enclosed in quotes.
4. Outputs only the specified column to the target file.


### License
This project is governed by a license, the details of which can be located in the accompanying file named 'LICENSE.' Please refer to this file for comprehensive information.
