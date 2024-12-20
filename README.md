# TrueNAS Configuration Backups
- Script to periodically backup a TrueNAS configuration file that can be used to <br/>
restore a TrueNAS pool to the specified configuration.
- The user can specify how many backup files to keep (e.g. up to 3 backup files).
- The configuration file is saved in the local file system and uploaded to Google Cloud.
- Exit status is sent through notifications using [Ntfy](https://ntfy.sh/)