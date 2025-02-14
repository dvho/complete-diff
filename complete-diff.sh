#!/bin/sh


# Create an 8-bit color map for outputs using ANSI escape codes from    https://devmemo.io/cheatsheets/terminal_escape_code/    where the colors have been rewritten to use printf to ensure that the escape sequences in the colorize_file_diff function, which leverage the sed utility, work consistently across different environments, including legacy systems
DARK_RED=$(printf '\033[1;38;5;88m')
WHITE=$(printf '\033[1;38;5;15m')
ORANGE_3=$(printf '\033[1;38;5;172m')
DARK_CYAN=$(printf '\033[1;38;5;36m')
DEEP_SKY_BLUE=$(printf '\033[1;38;5;39m')
DODGER_BLUE=$(printf '\033[1;38;5;33m')
GREEN=$(printf '\033[1;38;5;28m')
END_COLOR=$(printf '\033[0m') # this resets to default color

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create a function to check if a file is a text file...
is_text_file() {
    local file="$1" # ...get the file path...
    if file "$file" | grep -qE 'text|empty'; then #...and if it is a text file...
        return 0 #...return true...
    else # ...otherwise...
        return 1 #...return false
    fi
}

# Create a function to check if a directory is empty...
is_empty_dir() {
    if [ -d "$1" ] && [ -z "$(ls -A "$1")" ]; then # ...if the directory exists and is empty...
        return 0 # ...return true...
    else # ...otherwise...
        return 1 # ...return false
    fi
}

# Create a function to colorize the diff output...
colorize_file_diff() {
    # ...and, so the sed rules don't incorrectly color lines from the files themselves which contain <, > or |, create two temporary files...
    temp_file1=$(mktemp "$SCRIPT_DIR/tmp.XXXXXX")
    temp_file2=$(mktemp "$SCRIPT_DIR/tmp.XXXXXX")

    # ...and within them replace characters <, > and | with parsing characters ▛,▜ and ▐, respectively...
    sed 's/</▛/g; s/>/▜/g; s/|/▐/g' "$FILE_A" > "$temp_file1"
    sed 's/</▛/g; s/>/▜/g; s/|/▐/g' "$FILE_B" > "$temp_file2"

    # ...run side-by-side diff on the parsed copies...
    diff -y "$temp_file1" "$temp_file2" \
    | sed \
        -e "/|/s/^.*$/${GREEN}&${END_COLOR}/" \
        -e "/</s/^.*$/${DARK_RED}&${END_COLOR}/" \
        -e "/>/s/^.*$/${DARK_RED}&${END_COLOR}/" \
        | sed -e "s/▛/</g; s/▜/>/g; s/▐/|/g" # ...colorize the output using sed, where the first expression colors the common lines green, the second and third expressions color the lines unique to the first and second files, respectively, red, then pipe that output to another sed command that reverts the parsing characters, ▛, ▜ and ▐ with their original characters, <, > and |...

    rm "$temp_file1" "$temp_file2" # ...and remove the temporary files
}

# Prompt the user to drag and drop both folders
echo "Drag and drop the two folders to compare and hit Enter after each one:"
echo

# Read the first and second directory paths sequentially
read -r DIR_A
read -r DIR_B

# Trim any leading or trailing whitespace from the input
DIR_A=$(echo "$DIR_A" | xargs)
DIR_B=$(echo "$DIR_B" | xargs)

# Remove any trailing slashes from DIR_A and DIR_B
DIR_A="${DIR_A%/}"
DIR_B="${DIR_B%/}"

# Compute the common prefix...
common_part="$DIR_A" # ...initialize the common part with the first directory...
while [ -n "$common_part" ] && [ "${DIR_B#$common_part}" = "${DIR_B}" ] ; do # ...and while common part is not an empty string and the second directory does not start with the common part...
    common_part="${common_part%/*}" # ...remove the last part of the common part...
done # ...until the second directory starts with the common part...
common_part="${common_part%/}" # ...and remove any trailing slashes

# Display the directories for confirmation
echo
echo "${WHITE}First folder:${END_COLOR} ${DARK_CYAN}$DIR_A${END_COLOR}"
echo "${WHITE}Second folder:${END_COLOR} ${DARK_CYAN}$DIR_B${END_COLOR}"
echo

# Create a temporary file
temp_file=$(mktemp "$SCRIPT_DIR/tmp.XXXXXX")

# Use diff to recursively compare the directories, excluding all .git folders, Apple Double Files and all .DS_Store files, then save the output to the temporary file
diff -qr --exclude='.git' --exclude='._*' --exclude='.DS_Store' "$DIR_A" "$DIR_B" > "$temp_file"

# Sort the temporary file alphabetically
sort "$temp_file" -o "$temp_file"

# Initialize arrays for text file differences
TEXT_FILE_DIFFS_A=()
TEXT_FILE_DIFFS_B=()

# Read the diff output from the temporary file...
while IFS= read -r line; do # ...line by line...
    case "$line" in
        Files*)
            # ...and if a line contains the word "Files" extract the file paths...
            FILE_A=$(echo "$line" | sed -E 's/^Files (.+) and .+ differ$/\1/' | xargs)
            FILE_B=$(echo "$line" | sed -E 's/^Files .+ and (.+) differ$/\1/' | xargs)

            # ...use cmp to check if the files are truly different and skip if they are not...
            if cmp -s "$FILE_A" "$FILE_B"; then
                continue
            fi

            # ...get relative paths...
            relative_file_a="${FILE_A#$common_part/}"
            relative_file_b="${FILE_B#$common_part/}"

            # ...output that the files are different...
            echo "${WHITE}Files differ${END_COLOR}"
            echo "    ${ORANGE_3}$relative_file_a${END_COLOR}"
            echo "    ${ORANGE_3}$relative_file_b${END_COLOR}"
            echo

            # ...check if both files are text files...
            if is_text_file "$FILE_A" && is_text_file "$FILE_B"; then # ...and if they are...
                TEXT_FILE_DIFFS_A+=("$FILE_A")
                TEXT_FILE_DIFFS_B+=("$FILE_B")
            fi # ...add them to their respective arrays...
            ;;
        Only*)
            # ...if a line contains the word "Only" extract the directory paths...
            DIR_PATH=$(echo "$line" | sed -E 's/^Only in (.+): .+$/\1/')
            DIR_NAME=$(echo "$line" | sed -E 's/^Only in .+: (.+)$/\1/')
            PARENT_DIR=$(echo "$line" | sed -E 's/^Only in ([^:]+): .+$/\1/')

            if [ -d "$DIR_PATH/$DIR_NAME" ]; then # ...if it's a directory...
                if is_empty_dir "$DIR_PATH/$DIR_NAME"; then # ...and it's empty...
                    echo "${WHITE}Only in ${DARK_CYAN}$PARENT_DIR${END_COLOR}" # ...output the parent directory...
                    echo "    ${DARK_RED}$DIR_NAME${END_COLOR}" # ...and list the empty directory...
                    echo
                else # ...otherwise...
                    echo "${WHITE}Only in ${DARK_CYAN}$PARENT_DIR${END_COLOR}" # ...output the parent directory...
                    find "$DIR_PATH/$DIR_NAME" -type f \
                        ! -path '*/.git/*' \
                        ! -name '._*' \
                        ! -name '.DS_Store' | while read -r found_file; do # ...and list the files in the directory, excluding all .git folders, Apple Double Files and all .DS_Store files...
                        relative_file="${found_file#$DIR_PATH/}" # ...get the relative path...
                        echo "    ${DARK_RED}$relative_file${END_COLOR}" # ...and output the relative path...
                    done
                    echo
                fi
            else # ...otherwise...
                echo "${WHITE}Only in ${DARK_CYAN}$PARENT_DIR${END_COLOR}" # ...output the parent directory...
                echo "    ${DARK_RED}$DIR_NAME${END_COLOR}" # ...and list the file
                echo
            fi
            ;;
    esac
done < "$temp_file"

# Remove the temporary file
rm "$temp_file"

# Check if there are any text files that differ...
if [ ${#TEXT_FILE_DIFFS_A[@]} -gt 0 ]; then # ...if there are differing text files...
    echo
    echo "${WHITE}Text files that differ:${END_COLOR}" # ...output the differing text files...
    for i in "${!TEXT_FILE_DIFFS_A[@]}"; do # ...line by line...
        idx=$((i + 1))
        file_a="${TEXT_FILE_DIFFS_A[$i]}"
        file_b="${TEXT_FILE_DIFFS_B[$i]}"

        # ...get relative paths...
        relative_file_a="${file_a#$common_part/}"
        relative_file_b="${file_b#$common_part/}"

        echo "${WHITE}$idx. ${DEEP_SKY_BLUE}$relative_file_a${WHITE} vs ${DODGER_BLUE}$relative_file_b${END_COLOR}" # ...and output the relative paths
    done

    echo
    # Display the main prompt only once...
    echo "Enter the numbers of the files you want to diff (e.g., 1 2 3, or 'a' for all, or 'q' to Quit):"

    while true; do # ...and loop until the user quits...

        printf '> ' # ...using a minimal prompt once inside the loop...

        read -r SELECTION # ...and read the user input...

        if [ "$SELECTION" = "q" ] || [ "$SELECTION" = "Q" ]; then # ...listen for the quit command...
            break
        fi

        if [ "$SELECTION" = "a" ] || [ "$SELECTION" = "A" ]; then # ...listen for the all command...
            SELECTION=""
            for j in $(seq 1 ${#TEXT_FILE_DIFFS_A[@]}); do
                SELECTION+="$j "
            done
        fi

        IFS=' ,;' read -r -a SELECTED_INDICES <<< "$SELECTION" # ...split the input into an array of indices...

        for index in "${SELECTED_INDICES[@]}"; do # ...loop through the selected indices...

            idx=$((index - 1)) # ...get the index of the selected file...

            if [ $idx -ge 0 ] && [ $idx -lt ${#TEXT_FILE_DIFFS_A[@]} ]; then # ...if the index is valid get the file paths...
                FILE_A="${TEXT_FILE_DIFFS_A[$idx]}"
                FILE_B="${TEXT_FILE_DIFFS_B[$idx]}"

                # ...get the relative paths for display...
                relative_file_a="${FILE_A#$common_part/}"
                relative_file_b="${FILE_B#$common_part/}"

                echo
                echo "${WHITE}Difference between${END_COLOR}" # ...output the relative paths...
                echo "    ${DARK_CYAN}$relative_file_a${END_COLOR}"
                echo "    ${DARK_CYAN}$relative_file_b${END_COLOR}"
                echo
                colorize_file_diff "$FILE_A" "$FILE_B" # ...and colorize the diff outputs...
                echo
            else # ...otherwise...
                echo "Invalid selection: $((idx + 1))" # ...output an error message...
            fi
        done
    done
else # ...otherwise...
    echo "No differing text files found." # ...if there are no differing text files, output as such
fi