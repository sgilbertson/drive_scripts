# drive_scripts

Handy scripts (or at least ones I have found handy) related to disk drives

# get_drive_info.sh

Information-gathering script for my hard-disk collection.
The idea is to install a drive in a USB or SATA dock, and run the tool, perhaps repeating from time to time.

It prompts with a list of available drives, and asks you to select one.
The first time you run it on a given drive it also asks you for a name, which it uses in a symbolic link to the generated reports for that drive.
If you subsequently scan the same drive it uses the same symbolic link, so you can always access reports for the drive by that name.

Choose a name that will help you remember which drive you scanned.
For example, if you scan your system drive, you might call it "system", and if you have three backup drives, you might call them
"backup 1", "backup 2" and "backup 3".
You may want to put a label on the drive with that name.

The name of the actual report directory (under "reports") is a non-memorable unique ID.

## A.I.-generated Overview

`get_drive_info.sh` is a comprehensive disk documentation tool that collects and organizes detailed information about storage drives. The script gathers hardware details, SMART health data, partition layouts, and complete filesystem inventories, saving everything in a structured report directory. Each drive's data is stored in a UUID-based folder to ensure uniqueness across multiple scans, with optional symbolic links for easier access.

The script performs both quick metadata collection (disk model, partition tables, filesystem types) and thorough filesystem scans that catalog every directory and file on mounted partitions. Progress indicators keep you informed during long-running operations like file enumeration on large drives. All reports are saved as plain text files, making them easy to search, compare, and archive for drive management, backup verification, or historical record-keeping.

## Prerequisites

The script uses some specific tools, which you can install thus:

```sh
# Update package lists
sudo apt update

# Install required packages
# (you probably already have all of them except maybe smartmontools)
sudo apt install -y util-linux smartmontools findutils coreutils

# Verify installations
dpkg -l | grep -E 'util-linux|smartmontools|findutils|coreutils'
```

## If you find that two drives have the same "unique" ID

If you clone a drive, then later modify one of the two drives, they'll both have the same supposedly-unique ID.
To fix that, install one of the drives, and figure out which partition table type it has:

```sh
# substitute the actual device name for /dev/sdX
sudo blkid -s PTTYPE -o value /dev/sdX
```

**Warning:** Double-check that you have the correct device name before running the commands below, as they will modify the drive's partition table UUID.

If it reports that it's a GPT partition table, generate a new random PTUUID:

```sh
# substitute the actual device name for /dev/sdX
sudo sgdisk --disk-guid=R /dev/sdX
```

If it reports that it's a DOS or MBR table, generate a new random ID.

**DO NOT TRUST THIS METHOD** - I did this, and wound up with a corrupt partition table, which I had to repair using `testdisk`.

```sh
# substitute the actual device name for /dev/sdX
sudo sfdisk --disk-id /dev/sdX $(uuidgen | cut -c1-8)
# If it prints this error message, that's normal and acceptable:
#  Re-reading the partition table failed.: Device or resource busy
# It just means the OS will be using the old ID until you unmount and re-mount the drive.
```

This is likely to be a better method, but I haven't tried it yet:

```sh
# Replace with a safe unique ID (4 bytes from urandom)
ID=$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')
echo "New Disk ID: $ID"

# Patch only the 4 bytes at offset 0x1B8 (decimal 440)
echo -ne "\\x${ID:6:2}\\x${ID:4:2}\\x${ID:2:2}\\x${ID:0:2}" | \
  sudo dd of=/dev/sdX bs=1 seek=440 count=4 conv=notrunc
```

That's based on the standard DOS MBR Layout (512 bytes total):

| Offset  | Size | Description                                     |
| ------- | ---- | ----------------------------------------------- |
| `0x000` | 446  | Bootstrap code area                             |
| `0x1B8` | 4    | **Disk signature / ID** (used by Windows, etc.) |
| `0x1BC` | 2    | Usually zero or unused                          |
| `0x1BE` | 64   | Partition table entries (4×16 bytes each)       |
| `0x1FE` | 2    | MBR signature (must be `0x55AA`)                |

# summarize.sh


After running get_drive_info.sh on any number of drives, this script summarizes the results.
It looks for all the symbolic links in the reports/ directory and creates a row in a csv file 
for each drive, with key information such as disk model, serial number, size, health status, etc.

The resulting file, `drive_summary.csv` can be imported into a spreadsheet or otherwise manipulated.

# compare_all_drives.sh

After collecting drive data for multiple drives and partitions using `get_drive_info.sh`, this script compares the file lists for each pair of partitions, looking for differences and similarities.
It creates a CSV file indicating for each pair or partitions how many files are only in the first one, only in the second one, or on both.
It also prints a list of the top ten pairs with the most files in common.

Important: It can take a very long time to run, if you have a lot of partitions and/or a lot of files per partition.
