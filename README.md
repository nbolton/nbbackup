=== Welcome ===

`nbbackup` is a very simple backup script for Linux, which mounts a connected backup drive (identified from a list of valid backup drives) and performs a backup using either rsync or partimage.

=== Quick Usage ===

Backup specified path (from config file) in the background using rsync (archive, mirror), and check the backup drive before mounting. This will also automatically create a log file.

> nbbackup -fcb

Test to see if the backup drive specified in the config file is valid (this will mount and then unmount the first available drive).

> nbbackup -t


Read the [Readme README] for more info.
