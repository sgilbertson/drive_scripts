#!/bin/bash

# Compare all drive file listings to find duplicates and unique files
# Compares every pair of *all_files.txt files

set -euo pipefail

OUTPUT_CSV="drive_comparison.csv"

echo "Drive 1,Partition 1,Drive 2,Partition 2,Only in Drive 1,Only in Drive 2,In Both" > "$OUTPUT_CSV"

# Get all *all_files.txt files
FILES=(*/*all_files.txt)

echo "Found ${#FILES[@]} drive partitions to compare"
echo "This will generate $((${#FILES[@]} * (${#FILES[@]} - 1) / 2)) comparisons"
echo

# Compare each pair
for ((i=0; i<${#FILES[@]}; i++)); do
    FILE1="${FILES[i]}"
    DRIVE1=$(dirname "$FILE1")
    PART1=$(basename "$FILE1" | sed 's/partition_\(.*\)_all_files.txt/\1/')
    
    # Extract mount point - find the common prefix by taking first path and removing after first real directory
    # The mount point is everything up to and including the last / before actual content
    MOUNT1=$(head -1 "$FILE1")
    # Remove trailing filename to get just the directory structure, then extract mount root
    # Typically mount points are like /media/user/LABEL or /mnt/something
    if [[ "$MOUNT1" =~ ^(/[^/]+/[^/]+/[^/]+) ]]; then
        MOUNT1="${BASH_REMATCH[1]}"
    elif [[ "$MOUNT1" =~ ^(/[^/]+/[^/]+) ]]; then
        MOUNT1="${BASH_REMATCH[1]}"
    else
        MOUNT1=""
    fi
    
    for ((j=i+1; j<${#FILES[@]}; j++)); do
        FILE2="${FILES[j]}"
        DRIVE2=$(dirname "$FILE2")
        PART2=$(basename "$FILE2" | sed 's/partition_\(.*\)_all_files.txt/\1/')
        
        echo -ne "\rComparing $DRIVE1 (part $PART1) vs $DRIVE2 (part $PART2)...                    "
        
        # Extract mount point from FILE2
        MOUNT2=$(head -1 "$FILE2")
        if [[ "$MOUNT2" =~ ^(/[^/]+/[^/]+/[^/]+) ]]; then
            MOUNT2="${BASH_REMATCH[1]}"
        elif [[ "$MOUNT2" =~ ^(/[^/]+/[^/]+) ]]; then
            MOUNT2="${BASH_REMATCH[1]}"
        else
            MOUNT2=""
        fi
        
        # Normalize paths by removing mount point prefix
        # Create temporary files with normalized paths
        TMP1=$(mktemp)
        TMP2=$(mktemp)
        
        if [ -n "$MOUNT1" ]; then
            sed "s|^$MOUNT1/*||" "$FILE1" | sort > "$TMP1"
        else
            sort "$FILE1" > "$TMP1"
        fi
        
        if [ -n "$MOUNT2" ]; then
            sed "s|^$MOUNT2/*||" "$FILE2" | sort > "$TMP2"
        else
            sort "$FILE2" > "$TMP2"
        fi
        
        # Count differences
        ONLY_IN_1=$(comm -23 "$TMP1" "$TMP2" | wc -l)
        ONLY_IN_2=$(comm -13 "$TMP1" "$TMP2" | wc -l)
        IN_BOTH=$(comm -12 "$TMP1" "$TMP2" | wc -l)
        
        # Write to CSV
        echo "\"$DRIVE1\",\"$PART1\",\"$DRIVE2\",\"$PART2\",$ONLY_IN_1,$ONLY_IN_2,$IN_BOTH" >> "$OUTPUT_CSV"
        
        # Clean up
        rm -f "$TMP1" "$TMP2"
    done
done

echo -e "\rComparison complete!                                                      "
echo
echo "Results written to $OUTPUT_CSV"
echo
echo "Top 10 drive pairs with most files in common:"
tail -n +2 "$OUTPUT_CSV" | sort -t, -k7 -rn | head -10 | column -t -s,
