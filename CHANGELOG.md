# Changelog

All notable changes to dmu are documented in this file. Entries are listed newest first. Versions before 0.4.8 have no recorded dates.

## [1.6.7] - 2026-09-29

- Quoted file names and the mail subject in shell commands, and replaced rm/mkdir shell-outs with unlink/mkdir

## [1.6.6] - 2026-09-29

- Fixed process_h700_info deleting the bundled MegaCli RPM from the tools directory after installing it

## [1.6.5] - 2026-09-29

- Fixed message scanning on Linux systems without /var/log/messages: falls back to the kernel journal, or skips the scan if neither exists

## [1.6.4] - 2026-09-29

- Fixed Adaptec detection failing on systems without /etc/redhat-release

## [1.6.3] - 2026-09-29

- Fixed character classes that matched punctuation: [A-z] (also matches [ \ ] ^ _), [L,l], [E,e] and SAS106[4,8] now match only the intended letters and digits

## [1.6.2] - 2026-09-29

- Removed duplicate variable declarations and fixed array elements written as one-element slices (perl -w clean)

## [1.6.1] - 2026-09-29

- Fixed process_disk_info replacing Optimal with OK before the record was split, so stdout output still showed Optimal

## [1.6.0] - 2026-09-29

- Fixed get_messages_info passing an unset disk number to add_to_bad_disk_list in the Solaris filesystem case, and removed duplicate variable declarations

## [1.5.9] - 2026-09-29

- Fixed the already-running check: the [1|2] character class matched a pipe, and the full script path (rather than its name) was used as the ps pattern

## [1.5.8] - 2026-09-29

- Fixed Solaris 10 release check using a string comparison and stripping every zero (release year 10 became 1)

## [1.5.7] - 2026-09-29

- Fixed ServeRAID detection reusing a stale $command on later controllers, and string comparison of the controller number

## [1.5.6] - 2026-09-29

- Fixed Adaptec and ServeRAID tools never being installed: chmod was run on missing files (inverted test); now uses install_tool

## [1.5.5] - 2026-09-29

- Fixed LSI SAS path calling undefined get_ftp_file; bundled tools are now copied from the tools directory (added install_tool, removed unused Net::FTP)

## [1.5.4] - 2026-09-29

- Fixed -c calling an undefined print_change_log; it now prints CHANGELOG.md. Also removed the duplicate print_version subroutine

## [1.5.3] - 2026-09-29

- check_local_config was run twice (once before options were parsed); split path/version setup into init_local_config so hardware checks run once, and -h/-V/-c no longer create the temp directory. Also fixed version output which printed an empty script name

## [1.5.2] - 2026-09-29

- Fixed -n and -R options being rejected by getopts (removed unused -k)

## [1.5.1] - 2019-10-09

- Minor bug fixes

## [1.5.0] - 2013-07-14

- More code cleanup

## [1.4.9] - 2013-07-13

- Cleaned up code and added tools directory for Linux

## [1.4.8] - 2013-07-10

- Separated out changelog

## [1.4.7] - 2013-05-08

- Updated script and fix zpool disk identification

## [1.4.6] - 2011-01-31

- Removed debug code

## [1.4.5] - 2010-09-02

- Improved sd determination in Linux

## [1.4.4] - 2010-08-26

- Added support for IS3500

## [1.4.3] - 2010-08-16

- Fixed output zpools with one disk

## [1.4.2] - 2010-08-16

- Added support for PERC H700

## [1.4.1] - 2010-07-26

- Fixed error with mirror checking on ZFS pools

## [1.4.0] - 2010-07-23

- Excluded controllers other than c0 and c1 from zpool

## [1.3.9] - 2010-07-15

- Fixed zfs check for ATA disks on T1000

## [1.3.8] - 2010-07-14

- Fixed check for zfs mirrors

## [1.3.7] - 2010-07-14

- Added check for zfs mirrors

## [1.3.6] - 2010-07-14

- Removed legacy from zfs filesystem discovery

## [1.3.5] - 2010-07-14

- Fixed problem with sending email for errors on zpools

## [1.3.4] - 2010-07-14

- Fixed problem with detecting errors on zpools

## [1.3.3] - 2009-04-21

- Added check for existing running process

## [1.3.2] - 2009-01-20

- Improved filesystem determination on Linux

## [1.3.1] - 2009-01-20

- Added support for SAS1068

## [1.3.0] - 2008-12-25

- Added code for Solaris 10 machines with no zone packages

## [1.2.9] - 2008-12-25

- Fixed check for File::Slurp

## [1.2.8] - 2008-12-15

- Added support machines running ZFS on hardware raid

## [1.2.7] - 2008-12-15

- Added support for X4600

## [1.2.6] - 2008-11-25

- Fixed bug with mailing errors

## [1.2.5] - 2008-11-18

- Fixed bug with mailing errors on machine with raidctl

## [1.2.4] - 2008-11-14

- Updated raidctl support for patched raidctl on early Solaris 10 releases

## [1.2.3] - 2008-11-05

- Added Inital ZFS mirrored disk set support

## [1.2.2] - 2008-08-15

- Fixed mdcheck typo and removed cst from recipient list

## [1.2.1] - 2008-07-08

- Cleaned up SDS resync output

## [1.2.0] - 2008-07-08

- Fixed issue with SDS output

## [1.1.9] - 2008-07-08

- Fixed issue with SDS processing

## [1.1.8] - 2008-06-17

- Added dynapath output to disk list

## [1.1.7] - 2008-06-16

- Improved Dynapath support on Linux

## [1.1.6] - 2008-06-16

- Fixed issue with DLP on Linux

## [1.1.5] - 2008-06-09

- Added support for X4100 running Solaris 10

## [1.1.4] - 2008-06-09

- Improved filesystem determination

## [1.1.3] - 2008-06-09

- Fixed disk reporting for messages parsing for veritas disks

## [1.1.2] - 2008-06-04

- Fixed disk reporting for messages parsing

## [1.1.1] - 2008-06-04

- Fixed bug with reporting errors via email

## [1.1.0] - 2008-06-04

- More raidctl improvements

## [1.0.9] - 2008-06-03

- More raidctl handling fixes

## [1.0.8] - 2008-05-26

- Fixed raidctl handling on Solaris 10 U3 and greater

## [1.0.7] - 2008-05-26

- Fixed LSI SAS processing on RHEL 5

## [1.0.6] - 2008-05-25

- Improved support for Linux LVM

## [1.0.5] - 2008-05-25

- Add handling for being run as mdcheck

## [1.0.4] - 2008-05-25

- Cleaned up disk listing and added RHEL 5 support

## [1.0.3] - 2008-05-25

- Cleaned up filesystem listing

## [1.0.2] - 2008-05-25

- Added code to print changes since last update

## [1.0.1] - 2008-05-25

- Added code to fetch changelog from patch

## [1.0.0] - 2008-05-25

- Changed name to dmu in order to put into subversion

## [0.9.9] - 2008-05-24

- Cleaned up variable names

## [0.9.8] - 2008-05-08

- Added ss-eng-sun-l to email

## [0.9.7] - 2008-05-08

- Added support for Solaris 10 Update 5

## [0.9.6] - 2008-04-08

- Ignore IBM SAN resets

## [0.9.5] - 2008-01-17

- More raidctl fixes

## [0.9.4] - 2007-12-17

- Fixed raidctl output to deal with unmirrored devices

## [0.9.3] - 2007-12-11

- Removed prtdiag test which was slowing down check

## [0.9.2] - 2007-12-06

- Fixed raidctl processing on Solaris 10

## [0.9.1] - 2007-12-04

- Added support for T6300 T6320 T5120 T5220 and T6220

## [0.9.0] - 2007-12-02

- Improved raidctl check

## [0.8.9] - 2007-11-08

- Added support ServeRAID 5i Firmware 7.12.X requiring an updated version of ipssend

## [0.8.8] - 2007-10-02

- Added support for X4200 running Solaris x86

## [0.8.7] - 2007-10-02

- Workaround four Solaris 10 Update 4 on T2000

## [0.8.6] - 2007-08-21

- Ignore messages check if running as patrol

## [0.8.5] - 2007-08-18

- Fixed LSI SAS1064 Controller support on Linux

## [0.8.4] - 2007-07-22

- Added support for V445 and V245

## [0.8.3] - 2007-06-13

- Fixed error with diff

## [0.8.2] - 2007-04-15

- Send mail to cst.its if there is a failure

## [0.8.1] - 2007-04-13

- Fixed typo and disabled heat logging for the moment

## [0.8.0] - 2007-04-13

- Added more sanity checking before logging heat call or sending email

## [0.7.9] - 2007-04-13

- Added support for LSI SAS controller under FreeBSD

## [0.7.8] - 2007-04-12

- Changed mail behavior to only generate one email per event

## [0.7.7] - 2007-04-04

- Fixed filesystem name process to include /

## [0.7.6] - 2007-04-04

- Added -A switch to help in messages file processing and debugging

## [0.7.5] - 2007-03-27

- Ignore fibre-channel (SAN) devices in messages file

## [0.7.4] - 2007-03-26

- Added support to process messages file under Linux

## [0.7.3] - 2007-03-25

- Code cleanup and bug fixes

## [0.7.2] - 2007-03-24

- Cleaned up code to add disk to bad disk list

## [0.7.1] - 2007-03-23

- Improved log processing code

## [0.7.0] - 2007-03-08

- Added handling for ServeRAID 4Lx with updated BIOS

## [0.6.9] - 2007-03-08

- Added Okay as a valid status to ServeRAID output

## [0.6.8] - 2007-03-08

- Removed code to fetch heat id in responce prefix

## [0.6.7] - 2007-02-11

- Converted help to man file using pod2man

## [0.6.6] - 2007-02-10

- More cleanups

## [0.6.5] - 2007-02-10

- Cleaned up raidctl handling for Solaris

## [0.6.4] - 2007-02-10

- Split disk processing code into smaller subroutines and improve processing

## [0.6.3] - 2006-11-29

- Improved Patrol checking

## [0.6.2] - 2006-11-29

- Added support for T2000

## [0.6.1] - 2006-10-11

- Added code to add patrol to disk group

## [0.6.0] - 2006-10-11

- Improved check for running as patrol

## [0.5.9] - 2006-10-05

- Added ability to fetch ipssend

## [0.5.8] - 2006-10-04

- Cleaned up Linux Software Raid support

## [0.5.7] - 2006-09-29

- Added support for LSI1064 SAS controller

## [0.5.6] - 2006-09-26

- Fixed a bug with using patrol option

## [0.5.5] - 2006-09-26

- Added output for patrol

## [0.5.4] - 2006-09-22

- Fixed disksuit output to display OK rather than Okay

## [0.5.3] - 2006-09-11

- Added hostname to mail subject

## [0.5.2] - 2006-09-05

- Added code to allow patrol to run script

## [0.5.1] - 2006-09-04

- Added support for change in raidctl output

## [0.5.0] - 2006-09-04

- Cleaned up log file creation and deletion

## [0.4.9] - 2006-09-03

- Try to us lynx to post to heat php script if LWP not installed

## [0.4.8] - 2006-09-03

- Updated changelog code inline with other scripts

## [0.4.7]

- Fixed bug with update code

## [0.4.6]

- Added capability to log Heat calls

## [0.4.5]

- Removed use of /tmp as a temp directory

## [0.4.4]

- Improved LSI raid support for Solaris

## [0.4.3]

- Changed sys admin from R.Spindler to ss-eng-sun-l

## [0.4.2]

- Added check for zones on Solaris 10

## [0.4.1]

- Changed the getftp sub to do anonymous login only since patch now is only anonymous

## [0.4.0]

- Improved command line processing

## [0.3.9]

- Fixed bugs in mail option

## [0.3.8]

- Fixed incomplete mirror for disksuite reporting in mail option

## [0.3.7]

- Fixed resync reporting for disksuite in mail option

## [0.3.6]

- Added mapping of disk errors to vx devices

## [0.3.5]

- Added mapping of disk errors to disksuite devices

## [0.3.4]

- Added proactive parsing of dmesg for disk errors

## [0.3.3]

- Added code to check mirrors have two submirrors

## [0.3.2]

- Added code to show resync percentage

## [0.3.1]

- Added check to disksuite status

## [0.3.0]

- Added support to run without checking for latest version

## [0.2.9]

- Added support to Hotspare to ServRAID mirror checking

## [0.2.8]

- Fixed bug with autoupdate

## [0.2.7]

- Improved support for raidctl

## [0.2.6]

- Added self update code

## [0.2.5]

- Cleaned up code, used Getopt::Std

## [0.2.4]

- Added syslog support via logger

## [0.2.3]

- Improved support for ipsend command under linux

## [0.2.2]

- Added support for LSI controller on linux

## [0.2.1]

- Added support for software raid on linux

## [0.2.0]

- Added support for Freebsd and DPTI20

## [0.1.9]

- Changed test for Veritas to remove ERROR output

## [0.1.8]

- Fixed bug with disksuite metadisk handling

## [0.1.7]

- Added handling for proc output for DAC having stars in it

## [0.1.6]

- Added support for mail rather than mailx on RedHat

## [0.1.5]

- Added support for Serveraid

## [0.1.4]

- Added support for DPTI20

## [0.1.3]

- Added support for DAC960

## [0.1.2]

- Added support for Linux

## [0.1.1]

- Functionalised code

## [0.1.0]

- Remove need for IO::File

## [0.0.9]

- Added support for Veritas

## [0.0.8]

- Improved code to deal properly with sub mirrors

## [0.0.7]

- Added raidctl support for V440s

## [0.0.6]

- Added Solaris 8/9 support

## [0.0.5]

- Added -v switch.

## [0.0.4]

- Added -h switch.

## [0.0.3]

- Added -m switch.

## [0.0.2]

- Added -l switch.

## [0.0.1]

- Initial version.

