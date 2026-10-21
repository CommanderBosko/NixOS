# linecount

`tool.sh` prints the number of lines in each file you pass it, followed by a total.

## Usage

    ./tool.sh FILE...

Each file is reported on its own line as `<count> <path>`. The last line is the total across
all files that could be read.

## Requirements

Bash 4 or newer and the standard coreutils. No other dependencies are neccessary.

## Exit status

`0` on success, `1` if any file could not be read.
