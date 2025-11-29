#!/bin/bash

# After running get_drive_info.sh on any number of drives, this script summarizes the results.
# It looks for all the symbolic links in the reports/ directory and creates a row in a csv file
# for each drive, with key information such as disk model, serial number, size, health status, etc.

########################################
# Setup
########################################

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS_DIR="$SOURCE_DIR/reports"
OUTPUT_CSV="$SOURCE_DIR/drive_summary.csv"
mkdir -p "$REPORTS_DIR"

########################################
# CSV Header
######################################## 

echo "Disk Model,Disk Serial,Disk Size,Disk PTUUID,Overall Health,Number of Partitions,Partition Details" > "$OUTPUT_CSV"

########################################
# Process Each Drive
########################################

for LINK in *; do
    if [ -L "$LINK" ]; then
        DRIVE_DIR="$(readlink -f "$LINK")"
        
        # Extract info from general_disk_info.txt
        DISK_MODEL=$(grep "Device Model:" "$DRIVE_DIR/general_disk_info.txt" | head -1 | awk -F: '{print $2}' | xargs || echo "")
        DISK_SERIAL=$(grep "Serial Number:" "$DRIVE_DIR/general_disk_info.txt" | head -1 | awk -F: '{print $2}' | xargs || echo "")
        DISK_SIZE=$(grep "User Capacity:" "$DRIVE_DIR/general_disk_info.txt" | head -1 | awk -F: '{print $2}' | xargs || echo "")
        DISK_PTUUID=$(basename "$DRIVE_DIR")
        
        # Get most recent SMART report
        LATEST_SMART=$(ls -t "$DRIVE_DIR"/smart_report_*.txt 2>/dev/null | head -1)
        if [ -n "$LATEST_SMART" ]; then
            OVERALL_HEALTH=$(grep "SMART overall-health" "$LATEST_SMART" | awk -F: '{print $2}' | xargs || echo "")
        else
            OVERALL_HEALTH=""
        fi
        
        # Count partitions by counting partition_*_info.txt files
        NUM_PARTITIONS=$(ls "$DRIVE_DIR"/partition_*_info.txt 2>/dev/null | wc -l)
        
        # Build partition details
        PARTITION_DETAILS=""
        for PART_INFO in "$DRIVE_DIR"/partition_*_info.txt; do
            if [ -f "$PART_INFO" ]; then
                PART_NUM=$(grep "Partition Number:" "$PART_INFO" | awk -F: '{print $2}' | xargs || echo "")
                PART_FS=$(grep "Filesystem:" "$PART_INFO" | awk -F: '{print $2}' | xargs || echo "")
                PART_SIZE=$(grep "Size:" "$PART_INFO" | awk -F: '{print $2}' | xargs || echo "")
                if [ -n "$PART_NUM" ]; then
                    PARTITION_DETAILS+="$PART_NUM($PART_FS,$PART_SIZE); "
                fi
            fi
        done
        PARTITION_DETAILS=${PARTITION_DETAILS%; } # Remove trailing semicolon and space
        
        echo "\"$DISK_MODEL\",\"$DISK_SERIAL\",\"$DISK_SIZE\",\"$DISK_PTUUID\",\"$OVERALL_HEALTH\",\"$NUM_PARTITIONS\",\"$PARTITION_DETAILS\"" >> "$OUTPUT_CSV"
    fi
done

########################################
# Print results
########################################

echo
column -s, -t < "$OUTPUT_CSV"
echo
echo "Drive summary written to $OUTPUT_CSV"
