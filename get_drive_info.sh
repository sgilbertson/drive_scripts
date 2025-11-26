#!/usr/bin/env bash
set -euo pipefail

REPORTS_DIR="reports"
mkdir -p "$REPORTS_DIR"

########################################
# Progress Indicator Functions
########################################
show_step() {
    echo -e "\n\033[1;34m==> $1\033[0m"
}

progress_msg() {
    echo -ne "\r$1"
}

progress_done() {
    echo -e "\r$1 ✓"
}

########################################
# Drive Selection
########################################

echo "Attached drives:"
# Exclude loop and ram devices with -e 7
lsblk -d -e 7 -o NAME,SIZE,MODEL,TYPE
echo

read -rp "Enter whole-disk device name (e.g., sdc): " DEVNAME
DISK="/dev/$DEVNAME"

if [ ! -b "$DISK" ]; then
    echo "Error: $DISK is not a block device."
    exit 1
fi

########################################
# Disk UUID (PARTUUID for whole disk)
########################################

DISK_UNIQUE_ID=$(sudo blkid -s PTUUID -o value "$DISK" 2>/dev/null || true)

if [ -z "$DISK_UNIQUE_ID" ]; then
    echo "Warning: Disk has no PTUUID — trying fdisk identifier"
    DISK_UNIQUE_ID=$(sudo fdisk -l /dev/sda | grep "Disk identifier" | awk '{print $NF;}')
fi


if [ -z "$DISK_UNIQUE_ID" ]; then
    echo "Warning: Disk has no PTUUID or fdisk identifier — using synthetic ID"
    DISK_UNIQUE_ID="DISK-$(basename "$DISK")-$(date +%s)"
fi

echo "Using disk unique ID: $DISK_UNIQUE_ID"

UUID_DIR="$REPORTS_DIR/$DISK_UNIQUE_ID"
mkdir -p "$UUID_DIR"

echo
read -rp "Enter a symlink name for this drive: " LINKNAME
ln -sfn "$UUID_DIR" "$LINKNAME"

echo
echo "Documenting disk: $DISK"
echo "Output directory: $UUID_DIR"
echo

DATESTAMP=$(date +"%Y-%m-%d")

########################################
# General Disk Info
########################################

show_step "Collecting general disk info"

LSBLK_INFO=$(lsblk output -l "$DISK" 2>&1 || true)
FDISK_INFO=$(sudo fdisk -l "$DISK" 2>&1 || true)
SMARTCTL_INFO=$(sudo smartctl -i "$DISK" 2>&1 || true)

{
    echo "General Disk Information for $DISK"
    echo "Generated: $(date)"
    echo
    echo "$LSBLK_INFO"
    echo
    echo "$FDISK_INFO"
    echo
    echo "$SMARTCTL_INFO"
} > "$UUID_DIR/general_disk_info.txt"

########################################
# SMART disk-wide info
########################################

show_step "Collecting SMART data"

progress_msg "Running SMART health…"
SMART_HEALTH=$(sudo smartctl -H "$DISK" 2>&1 || true)
progress_done "SMART health collected"

progress_msg "Running full SMART report…"
SMART_FULL=$(sudo smartctl -x "$DISK" 2>&1 || true)
progress_done "Full SMART report collected"

{
    echo "SMART Health Summary for $DISK"
    echo "Generated: $(date)"
    echo
    echo "$SMART_HEALTH"
} > "$UUID_DIR/smart_health.txt"

{
    echo "SMART Full Report for $DISK"
    echo "Generated: $(date)"
    echo
    echo "$SMART_FULL"
} > "$UUID_DIR/smart_report_$DATESTAMP.txt"

########################################
# Partition Enumeration
########################################

PARTS=$(lsblk -lnpo NAME "$DISK" | sed '1d')

if [ -z "$PARTS" ]; then
    echo "Disk has no partitions."
    exit 0
fi

echo "Found partitions:"
echo "$PARTS"

########################################
# Per-Partition Scanning
########################################

for PART in $PARTS; do
    PARTNUM=$(echo "$PART" | sed 's/[^0-9]*//g')

    show_step "Scanning partition $PART (partition number $PARTNUM)"

    P_FSTYPE=$(lsblk -no FSTYPE "$PART" 2>/dev/null || sudo lsblk -no FSTYPE "$PART")
    P_LABEL=$(lsblk -no LABEL "$PART" 2>/dev/null || sudo lsblk -no LABEL "$PART")
    P_UUID=$(lsblk -no UUID "$PART" 2>/dev/null || sudo lsblk -no UUID "$PART")
    P_MOUNT=$(lsblk -no MOUNTPOINT "$PART" 2>/dev/null || sudo lsblk -no MOUNTPOINT "$PART")
    P_SIZE=$(lsblk -no SIZE "$PART" 2>/dev/null || sudo lsblk -no SIZE "$PART")

    INFO_FILE="$UUID_DIR/partition_${PARTNUM}_info.txt"

    {
        echo "Partition: $PART"
        echo "Partition Number: $PARTNUM"
        echo "Size: $P_SIZE"
        echo "Filesystem: $P_FSTYPE"
        echo "Label: $P_LABEL"
        echo "UUID: $P_UUID"
        echo "Mountpoint: ${P_MOUNT:-'(not mounted)'}"
        echo

        if [ -n "$P_MOUNT" ]; then
            echo "Used / Free / Total:"
            df -h "$P_MOUNT"
        fi
    } > "$INFO_FILE"

    ########################################
    # Directory Scanning with Progress
    ########################################

    if [ -z "$P_MOUNT" ]; then
        echo "Partition not mounted — skipping directory scan."
        continue
    fi

    # --- Top-level dirs ---
    progress_msg "  Listing top-level directories…"
    ls -1 "$P_MOUNT" > "$UUID_DIR/partition_${PARTNUM}_top_level_dirs.txt" 2>/dev/null || true
    progress_done "  Top-level directories listed"

    # --- All directories ---
    progress_msg "  Counting directories…"
    DIRCOUNT=$(find "$P_MOUNT" -type d 2>/dev/null | wc -l)
    progress_done "  $DIRCOUNT directories detected"

    progress_msg "  Scanning all directories… 0 / $DIRCOUNT"
    # Open fd 3 for writing to the file
    exec 3> "$UUID_DIR/partition_${PARTNUM}_all_dirs.txt"
    COUNT=0
    find "$P_MOUNT" -type d 2>/dev/null | while read -r d; do
        COUNT=$((COUNT+1))
        echo "$d" >&3
        progress_msg "  Scanning all directories… $COUNT / $DIRCOUNT"
    done
    progress_done "  Directory scan completed ($DIRCOUNT dirs)"

    # --- All files ---
    progress_msg "  Counting files…"
    FILECOUNT=$(find "$P_MOUNT" -type f 2>/dev/null | wc -l)
    progress_done "  $FILECOUNT files detected"

    progress_msg "  Scanning all files… 0 / $FILECOUNT"
    # Open fd 3 for writing to the file
    exec 3> "$UUID_DIR/partition_${PARTNUM}_all_files.txt"
    COUNT=0
    find "$P_MOUNT" -type f 2>/dev/null | while read -r f; do
        COUNT=$((COUNT+1))
        echo "$f" >&3
        progress_msg "  Scanning all files… $COUNT / $FILECOUNT"
    done
    progress_done "  File scan completed ($FILECOUNT files)"

done

echo
echo "All reports completed successfully."
echo "Location: $UUID_DIR"
