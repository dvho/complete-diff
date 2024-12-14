# Complete Diff

User-friendly recursive directory diffing for macOS with some extended capabilities to the `diff` utility.

## Features

- **Exclusion Logic**: Knows to skip unnecessary files like AppleDouble and `.DS_Store` files.
- **Verification**: Further integrates `cmp` for byte-by-byte comparison to verify differences.
- **Space Handling**: Robust handling of file and directory names with spaces.
- **User-Friendly Output**: Clear and concise output for easy interpretation of differences.
- **Line-By-Line Options:** Electively get granular with a line-by-line comparison of any chosen text files.

## Requirements

- **Unix-like shell**: The script requires a Unix-like shell environment, e.g. those included with macOS (`bash`, `zsh`, `dash`, `ksh`, `tcsh`, `csh` or others).
- **sed**: This utility is part of the POSIX standard and is included by default in macOS.

## Usage

1. Run the script:
   ```bash
   ./complete-diff.sh
   ```

2. Follow the prompts to enter the paths of the two directories you wish to compare. Each path should be entered on a separate line.

3. Following the initial output, electively inspect line-by-line differences of any differing text files.
