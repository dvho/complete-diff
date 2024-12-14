#!/bin/sh


# Create an 8 bit color map for outputs using    https://devmemo.io/cheatsheets/terminal_escape_code/
DARK_RED="\x1b[1m\x1b[38;5;88m"
WHITE="\x1b[1m\x1b[38;5;15m"
ORANGE_3="\x1b[1m\x1b[38;5;172m"
DARK_CYAN="\x1b[1m\x1b[38;5;36m"
DEEP_SKY_BLUE="\x1b[1m\x1b[38;5;39m"
DODGER_BLUE="\x1b[1m\x1b[38;5;33m"
GREEN="\x1b[1m\x1b[38;5;28m"
END_COLOR="\x1b[0m" # this resets to default color

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to check if a file is a text file
is_text_file() {
    local file="$1"
    if file "$file" | grep -qE 'text|empty'; then
        return 0
    else
        return 1
    fi
}

# Function to colorize diff output
colorize_diff() {
    diff -y "$@" | sed \
    -e "/[|]/ s/^.*$/${GREEN}&${END_COLOR}/" \
    -e "/</ s/^.*$/${DARK_RED}&${END_COLOR}/" \
    -e "/>/ s/^.*$/${DARK_RED}&${END_COLOR}/"
}

# Prompt the user to drag and drop both folders
echo "Drag and drop the two folders to compare and hit Enter after each one:"
echo

# Read the first directory path
read -r DIR_A
# Read the second directory path
read -r DIR_B

# Trim any leading or trailing whitespace from the input
DIR_A=$(echo "$DIR_A" | xargs)
DIR_B=$(echo "$DIR_B" | xargs)

# Remove any trailing slashes from DIR_A and DIR_B
DIR_A="${DIR_A%/}"
DIR_B="${DIR_B%/}"

# Compute the common prefix
common_part="$DIR_A"
while [ "${DIR_B#$common_part}" = "${DIR_B}" ] ; do
    common_part="${common_part%/*}"
done
common_part="${common_part%/}"

# Display the directories for confirmation
echo
echo "${WHITE}First folder:${END_COLOR} ${DARK_CYAN}$DIR_A${END_COLOR}"
echo "${WHITE}Second folder:${END_COLOR} ${DARK_CYAN}$DIR_B${END_COLOR}"
echo

# Arrays to store text files that differ
declare -a TEXT_FILE_DIFFS_A
declare -a TEXT_FILE_DIFFS_B

# Create a temporary file
temp_file=$(mktemp "$SCRIPT_DIR/tmp.XXXXXX")

# Use diff to compare the directories and save the output to the temporary file
diff -qr "$DIR_A" "$DIR_B" > "$temp_file"

# Initialize arrays for text file differences
TEXT_FILE_DIFFS_A=()
TEXT_FILE_DIFFS_B=()

# Read the diff output from the temporary file
while IFS= read -r line; do
    case "$line" in
        Files*)
            # Extract file paths
            FILE_A=$(echo "$line" | sed -E 's/^Files (.+) and .+ differ$/\1/' | xargs)
            FILE_B=$(echo "$line" | sed -E 's/^Files .+ and (.+) differ$/\1/' | xargs)

            # Ignore .DS_Store and AppleDouble files
            if [ "$(basename "$FILE_A")" = ".DS_Store" ] || [ "$(basename "$FILE_B")" = ".DS_Store" ]; then
                continue
            fi
            if [ "$(basename "$FILE_A")" = ._* ] || [ "$(basename "$FILE_B")" = ._* ]; then
                continue
            fi

            # Use cmp to check if files are truly different
            if cmp -s "$FILE_A" "$FILE_B"; then
                # Files are identical, skip output
                continue
            fi

            # Get relative paths
            relative_file_a="${FILE_A#$common_part/}"
            relative_file_b="${FILE_B#$common_part/}"

            # Output that the files are different
            echo "${WHITE}Files differ${END_COLOR}"
            echo "    ${ORANGE_3}$relative_file_a${END_COLOR}"
            echo "    ${ORANGE_3}$relative_file_b${END_COLOR}"
            echo

            # Check if both files are text files
            if is_text_file "$FILE_A" && is_text_file "$FILE_B"; then
                # Add files to the arrays
                TEXT_FILE_DIFFS_A+=("$FILE_A")
                TEXT_FILE_DIFFS_B+=("$FILE_B")
            fi
            ;;
        Only*)
            # Extract file path and name
            FILE_PATH=$(echo "$line" | sed -E 's/^Only in (.+): .+$/\1/' | xargs)
            FILE_NAME=$(echo "$line" | sed -E 's/^Only in .+: (.+)$/\1/')

            # Ignore .DS_Store and AppleDouble files
            if [ "$FILE_NAME" = ".DS_Store" ]; then
                continue
            fi
            if [ "$FILE_NAME" = ._* ]; then
                continue
            fi

            # Get full path and relative path
            FULL_PATH="$FILE_PATH/$FILE_NAME"
            relative_file="${FULL_PATH#$common_part/}"

            # Output that the file is only in one directory
            echo "${WHITE}Only in ${DARK_CYAN}$(dirname "$relative_file")${END_COLOR}"
            echo "    ${DARK_RED}$(basename "$relative_file")${END_COLOR}"
            echo
            ;;
    esac
done < "$temp_file"

# Remove the temporary file
rm "$temp_file"

# Check if there are any text files that differ
if [ ${#TEXT_FILE_DIFFS_A[@]} -gt 0 ]; then
    echo
    echo "${WHITE}Text files that differ:${END_COLOR}"
    for i in "${!TEXT_FILE_DIFFS_A[@]}"; do
        idx=$((i + 1))
        file_a="${TEXT_FILE_DIFFS_A[$i]}"
        file_b="${TEXT_FILE_DIFFS_B[$i]}"

        # Get relative paths
        relative_file_a="${file_a#$common_part/}"
        relative_file_b="${file_b#$common_part/}"

        echo "${WHITE}$idx. ${DEEP_SKY_BLUE}$relative_file_a${WHITE} vs ${DODGER_BLUE}$relative_file_b${END_COLOR}"
    done

    echo
    # Display the prompt only once
    echo "Enter the numbers of the files you want to diff (e.g., 1 2 3, or 'a' for all, or 'q' to Quit):"

    while true; do
        # Minimal prompt inside the loop
        printf '> '
        # Read user input (without repeating the prompt)
        read -r SELECTION

        if [ "$SELECTION" = "q" ] || [ "$SELECTION" = "Q" ]; then
            break
        fi

        if [ "$SELECTION" = "a" ] || [ "$SELECTION" = "A" ]; then
            SELECTION=""
            for j in $(seq 1 ${#TEXT_FILE_DIFFS_A[@]}); do
                SELECTION+="$j "
            done
        fi

        # Split SELECTION into an array
        IFS=' ,;' read -r -a SELECTED_INDICES <<< "$SELECTION"

        for index in "${SELECTED_INDICES[@]}"; do
            # Adjust index to zero-based
            idx=$((index - 1))
            # Check if index is within bounds
            if [ $idx -ge 0 ] && [ $idx -lt ${#TEXT_FILE_DIFFS_A[@]} ]; then
                FILE_A="${TEXT_FILE_DIFFS_A[$idx]}"
                FILE_B="${TEXT_FILE_DIFFS_B[$idx]}"

                # Get relative paths for display
                relative_file_a="${FILE_A#$common_part/}"
                relative_file_b="${FILE_B#$common_part/}"

                echo
                echo "${WHITE}Difference between${END_COLOR}"
                echo "    ${DARK_CYAN}$relative_file_a${END_COLOR}"
                echo "    ${DARK_CYAN}$relative_file_b${END_COLOR}"
                echo
                colorize_diff "$FILE_A" "$FILE_B"
                echo
            else
                echo "Invalid selection: $((idx + 1))"
            fi
        done
    done
else
    echo "No differing text files found."
fi