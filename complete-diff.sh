#!/bin/bash

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

# Display the directories for confirmation
echo
echo "First folder: $DIR_A"
echo "Second folder: $DIR_B"
echo

# Use diff to compare the directories and format the output
diff -qr "$DIR_A" "$DIR_B" | while read -r line; do
    if [[ $line == Files* ]]; then
        # Extract file paths using sed to handle spaces correctly
        FILE_A=$(echo "$line" | sed -E 's/^Files (.+) and .+ differ$/\1/' | xargs)
        FILE_B=$(echo "$line" | sed -E 's/^Files .+ and (.+) differ$/\1/' | xargs)
        
        # Ignore .DS_Store files
        if [[ $(basename "$FILE_A") == ".DS_Store" || $(basename "$FILE_B") == ".DS_Store" ]]; then
            continue
        fi

        # Ignore AppleDouble files
        if [[ $(basename "$FILE_A") == ._* || $(basename "$FILE_B") == ._* ]]; then
            continue
        fi

        # Use cmp to check if files are truly different
        if cmp -s "$FILE_A" "$FILE_B"; then
            # Files are identical, skip output
            continue
        fi

        # Otherwise output that the files are different according to the following format
        echo "Files"
        echo "    $FILE_A"
        echo "and"
        echo "    $FILE_B"
        echo "differ"
        echo

    elif [[ $line == Only* ]]; then

        # Extract file path and name using sed to handle spaces correctly
        FILE_PATH=$(echo "$line" | sed -E 's/^Only in (.+): .+$/\1/' | xargs)
        FILE_NAME=$(echo "$line" | sed -E 's/^Only in .+: (.+)$/\1/')

        # Ignore .DS_Store files
        if [[ $FILE_NAME == ".DS_Store" ]]; then
            continue
        fi

        # Ignore AppleDouble files
        if [[ $FILE_NAME == ._* ]]; then
            continue
        fi

        # Format for files only in one directory
        echo "Only in"
        echo "    $FILE_PATH"
        echo "$FILE_NAME"
        echo

    fi
done