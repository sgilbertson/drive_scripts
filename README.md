# drive_scripts

Handy scripts (or at least ones I have found handy) related to disk drives

# get_drive_info.sh

Information-gathering script for my hard-disk collection.
The idea is to install a drive in a USB or SATA dock, and run the tool, perhaps repeating from time to time.

It prompts with a list of available drives, and asks you to select one.
The first time you run it on a given drive it also asks you for a name, which it uses in a symbolic link to the generated reports for that drive.
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
# (you probably alreday have all of them except maybe smartmontools)
sudo apt install -y util-linux smartmontools findutils coreutils

# Verify installations
dpkg -l | grep -E 'util-linux|smartmontools|findutils|coreutils'
```