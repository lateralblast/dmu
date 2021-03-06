![alt tag](https://raw.githubusercontent.com/lateralblast/dmu/master/dmu.jpg)

DMU
===

Disk Monitoring Utility

Introduction
------------

dmu is a tool for checking software and hardware mirroring on a number
of Unix platforms.

Some features of dmu:

Supports multiple mirroring types and controllers in the same machine.

Supports reporting via email and syslog.

Supports the following software and hardware based mirroring:

- Solaris Volume Manager
- Veritas Volume Manager
- Solaris zpool
- Solaris raidctl
- Linux software mirroring
- Linux IBM ServeRAID 4lx, 4mx, 5i, 6i, 7, 7k, 8i
- Linux LSI MegaRAID SAS
- Linux Adaptec RAID Controllers
- FreeBSD LSI
- FreeBSD raidctl
- Linux Dynapath
- Linux DAC960
- Linux LSI SASx36
- Linux PERC H700

Usage
-----

```
dmu [OPTIONS]

-h Display help
-V Display version information
-c Display change log
-l Display list of mirrored disks
-f Display warning messages if any (during this hour)
-F Display warning messages if any (during this day)
-A Display warning messages if any
-m If an error is found send email
-s If an error is found create syslog message
-t Induce false errors (for testing purposes)
-n Run in non network mode (no check for updates)
-P Print error codes for Patrol
-v Verbose output
```

Examples
--------

Show disk information including status:

```
dmu -l
```

Mail errors if they are found:

```
dmu -m
```

Display warning messages created during this hour:

```
dmu -f
```

Introduce false errors and send email:

```
dmu -m -t
```
