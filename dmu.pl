#!/usr/bin/env perl

# Name:         dmu (Disk Monitoring Utility)
# Version:      1.5.0
# Release:      1
# License:      Open Source
# Group:        System
# Source:       N/A
# URL:          http://lateralblast.com.au/
# Distribution: Solaris and Linux
# Vendor:       UNIX
# Packager:     Richard Spindler <richard@lateralblast.com.au>
# Description:  Hardware and software disk mirror monitoring script 
#               Supports:
#               Solaris Volume Manager
#               Veritas Volume Manager
#               Solaris Zpool
#               Solaris raidctl
#               Linux software mirroring
#               Linux IBM ServeRAID 4lx, 4mx, 5i, 6i, 7, 7k, 8i
#               Linux LSI MegaRAID SAS
#               Linux Adaptec RAID Controllers
#               FreeBSD LSI
#               Linux Dynapath
#               Linux DAC960
#               Linux LSI SASx36
#               Linux PERC H700

use strict;
use Getopt::Std;
use Net::FTP;
use File::Basename;
use Cwd;

# Initialise global variables

my %option; 
my $verbose=0; 
my $file_system; 
my $zone_name; 
my $date_file; 
my @change_log; 
my $tools_dir;
my $coder_email="richard\@lateralblast.com.au";
my $report_email="Report.Receiver\@vendor.com";
my $disk_slice; 
my $marker=0; 
my @bad_disk_list; 
my @sds_info; 
my @raidctl_info; 
my @fs_list; 
my @i2o_info; 
my @veritas_info; 
my @ibmraid_info; 
my @freebsd_info; 
my @swmirror_info; 
my @lsi_info; 
my @adaptec_info; 
my $mail_report=0; 
my @zfs_info;
my @h700_info; 
my @sasx36_info; 
my @device_list;
my $script_file=$0; 
my $os_version=`uname -a`; 
my @dac960_info; 
my $adaptec_test=0; 
my $dac960_test=0; 
my $sds_test=0; 
my $veritas_test=0; 
my $raidctl_test=0; 
my $i2o_test=0; 
my $ibmraid_test=0; 
my $freebsd_test=0; 
my $swmirror_test=0; 
my $lsi_test=0; 
my $zfs_test; 
my $errors=0; 
my $email_address;
my $command_line; 
my $date_no; 
my $version_file;
my $dynapath_test=0; 
my @dynapath_info;
my $dynapath_command="/usr/local/dynapath/bin/dpcli";
my $file_slurp=0;
my $script_info;
my $version_info;
my $packager_info;
my $vendor_info;
my $script_name=$0;
my @script_file;
my $temp_dir;
my $output;

chomp($os_version);

# Check local configuration

check_local_config();
check_file_slurp();

# Get command line options

getopts("cfhlk:mstvAFPVd:",\%option) or print_usage();

#
# Check only one copy running
#

do_run_test();

# Stick command line options in a string
# This is done so when we do a self update
# the script is re-run with the same options 

foreach (keys %option) {
  $command_line="-$_ $command_line";
}

# list option, verbose output

if ($option{'l'}) {
  $verbose=1;
}
else {
  $verbose=0;
}

# Create a file name with the date
# If creating trouble tickets we don't 
# want to create more than one per day

$date_no=`date +\%d\%m\%y`;
chomp($date_no);
$date_file="$temp_dir/mdlog$date_no";

# Set email recipient based on mode

if ($option{'d'}) {
  $email_address=$coder_email;
  if (-e "$option{'d'}") {
    process_debug_file();
  }
  else {
    print "File: $option{'d'} does not exist!\n";
    exit;
  }
}
else {
  $email_address=$report_email;
}


##################################################################
# Check that a copy of script is not already running 
##################################################################

sub do_run_test {
  my $run_test;
  $run_test=`ps -ef |egrep '$script_name|mdcheck' |grep -v grep |grep -v vim |wc -l`;
  chomp($run_test);
  $run_test=~s/ //g;
  if ($run_test!~/^[1|2]$/) {
    print "$script_name is already running\n";
    exit;
  }
  return;
}

##################################################################
# This function is to test the whether the File::Slurp module is 
# loaded in this OS's perl.
##################################################################

sub check_file_slurp {
  my $file_slurp_test;
  if ((!$option{'R'})&&(!$option{'h'})) {
    eval "use File::Slurp"; $file_slurp_test=$@?0:1;
    if ($file_slurp_test) {
      $file_slurp=1;
                }
    else {  
      $file_slurp=0;
    }
  }
  return;
}

# If running on Solaris 10 check that we are running in the global zone

if ($os_version=~/SunOS/) {
  if ($os_version=~/5\.10|5\.11/) {
    $zone_name=`/usr/bin/zonename`;
    chomp($zone_name);
    if ($zone_name!~/[A-z]/) {
      $zone_name="global";
    }
    if ($zone_name!~/global/) {
      print "Script must be run on global zone\n";
      exit;
    }
  }
}

# Code to read in a file

sub read_a_file {
  my $file_name=$_[0];
  my @file_info;
  if ($file_slurp eq 0) {
    @file_info=`cat $file_name`;
  }
  else {  
    @file_info=read_file($file_name);
  }
  return @file_info;
}

# Code to process a debug file 

sub process_debug_file {
  my $tester=read_a_file($option{'d'});
  if ($tester=~/State Reloc Hot Spare/) {
    $sds_test=1;
    @sds_info=read_a_file($option{'d'});
    process_sds_info(); 
  }
  process_disk_info();
  exit;
}

# Search Linux device list

sub search_device_list {
  my $search_string=$_[0]; 
  my $disk_group=$_[1]; 
  my $suffix;
  my $record; 
  my $disk_name="unknown"; 
  my $number=0;
  foreach $record (@device_list) {
    if ($record=~/$search_string/) {
      ($disk_name,$suffix)=split('\|',$record);
      if ($disk_group!~/[0-9]/) {
        return($disk_name);
      }
      else {
        if ($number=~/$disk_group/) {
          return($disk_name);
        }
        else {
          $number++;
        }     
      }
    }
  }
  return;
}


# Build device list with mappings
#
# Create an array eg sda|LSI1064
# 

sub build_linux_device_list {
  my $record; 
  my $disk_number; 
  my $sd_number=0; 
  my $prefix; 
  my $controller;
  my @scsi_info=`cat /proc/scsi/scsi`; 
  my $id; 
  my $suffix; 
  my $channel; 
  my $lun; 
  my $model; 
  my $disk_name; 
  my $model; 
  my $id; 
  my $channel;
  my $number; 
  my $type;
  my $vendor; 
  my $temp_name; 
  my $min_number; 
  my $array_size;
  for ($counter=0; $counter<@scsi_info; $counter++) {
    $record=$scsi_info[$counter];
    chomp($record); 
    if ($record=~/Host/) {
      $number=$counter+2;
      $type=$scsi_info[$number];
      chomp($type);
      ($prefix,$controller,$channel,$id,$lun)=split(":",$record);
      $controller=~s/Channel//g;
      $controller=~s/scsi//g;
      $controller=~s/ //g;
      $controller=int($controller);
      $id=~s/^0//g;
      $id=int($id);
      if ($counter < 3) {
        $min_number=$controller;
      }
      $number=$counter+1;
      $model=$scsi_info[$number];
      chomp($model);
      if (($type!~/Enclosure/)&&($model!~/ATA|ROM|DVD|LCD|Floppy/)) {
        ($prefix,$model)=split("Model:",$model);
        ($model,$suffix)=split("Rev:",$model);
        $sd_number=$controller-$min_number+$id;
        $disk_name=chr($sd_number+97);
        $disk_name="sd$disk_name";
        $temp_name=search_device_list($model);
        if ($temp_name=~/[A-z]/) {
          $temp_name=$device_list[-1];
          ($temp_name,$suffix)=split('\|',$temp_name);
          $temp_name=~s/sd//g;
          $temp_name=ord($temp_name);
          $temp_name++;
          $temp_name=chr($temp_name);
          $disk_name="sd$temp_name";
          $array_size=@device_list; 
          $device_list[$array_size]="$disk_name|$model";
        }
        else {
          $device_list[$sd_number]="$disk_name|$model";
        }
        $disk_name="";
      }
    } 
  }
  return;
}

# Check the local configuration including determining disk mirroring

sub check_local_config {
  my $i2o_command; 
  my $ibmraid_command; 
  my $sds_command; 
  my $raidctl_command; 
  my $veritas_command; 
  my $freebsd_command; 
  my $counter; 
  my $record; 
  my $monitor_user_test; 
  my $lsi_command; 
  my $platform_test; 
  my $raidctl_output="$temp_dir/rdstatus"; 
  my $output="$temp_dir/$script_name.log"; 
  my $ips_string="/proc/scsi/ips"; 
  my $tester; 
  my $adaptec_proc="/proc/scsi/aacraid"; 
  my $adaptec_command; 
  my $adaptec_tool; 
  my $adaptec_no; 
  my $serveraid_no; 
  my $firmware_test; 
  my $firmware_command; 
  my $suffix;
  my $ibmraid_tool; 
  my $release_test; 
  my $prefix;
  my $tools_file; 
  my $command; 
  my $module_test; 
  my $man_file; 
  my $controller_no; 
  my $zfs_command; 
  my $raidctl_version; 
  my $ufs_test; 
  my $h700_test;
  my $man_dir="/usr/local/share/man/man1";
  my $sasx36_test; 
  my $zpool_name; 
  my @zpool_list;
  my $user_id=`id -u`;
  my $home_dir=`echo \$HOME`;
  my $dir_name=basename($script_name);
  $tools_dir=dirname($0);
  if ($tools_dir!~/[A-z]/) {
    $tools_dir=getcwd;  
  }
  $tools_dir="$tools_dir/tools";
  $vendor_info=search_script("Vendor");
  $packager_info=search_script("Packager");
  $version_info=search_script("Version");
  chomp($user_id);
  chomp($home_dir);
  if ($user_id=~/^0$/) {
    $temp_dir="/var/log/$dir_name";
  }
  else {
    $temp_dir="$home_dir/.$dir_name";
  }
  if (! -e "$temp_dir") {
    system("mkdir $temp_dir");
  }
  check_file_slurp();
  if ($os_version=~/[L,l]inux/) {
    # Build device mappings
    if (-e "/proc/scsi/scsi") {
      build_linux_device_list();
    }
    # Check for Dell PERC H700
    if (-e "/proc/scsi/scsi") {
      $h700_test=`cat /proc/scsi/scsi |grep 'H700'`;
      chomp($h700_test);
      if ($h700_test=~/H700/) {
        $h700_test=1;
        process_h700_info();
      }
      else {
        $h700_test=0;
      } 
    }
    # Check for LSI SASx36 
    if (-e "/proc/scsi/scsi") {
      $sasx36_test=`cat /proc/scsi/scsi |grep 'SASX36'`;
      chomp($sasx36_test);
      if ($sasx36_test=~/SASX36/) {
        $sasx36_test=1;
        process_sasx36_info();
      }
      else {
        $sasx36_test=0;
      } 
    }
    # Check for DAC960
    if (-e "/proc/rd/status") {
      $dac960_test=1;
      system("cat /proc/rd/c0/current_status |grep -v October > $raidctl_output");
      @dac960_info=`cat $raidctl_output`;
      if (-e "$raidctl_output") {
        system("rm $raidctl_output");
      }
      process_dac960_info();
    }
    # Check for I2O
    if (-e "/proc/scsi/dpt_i2o/0") {
      $i2o_test=1;
      $i2o_command="cat /proc/scsi/dpt_i2o/0";
      @i2o_info=`$i2o_command`;
      process_i2o_info(); 
    }
    # Check for Adaptec
    if ((-e "$adaptec_proc/0")||(-e "$adaptec_proc/1")||(-e "$adaptec_proc/2")||(-e "/sys/module/aacraid/version")) {
      # If we have Adaptec check we have arcconf 
      $release_test=`cat /etc/redhat-release`;
      chomp($release_test);
      if ($release_test=~/release 5/) {
        $adaptec_command="/usr/local/bin/arcconfel5";
        $adaptec_tool="$tools_dir/arcconfel5";
      }
      else {
        $adaptec_command="/usr/local/bin/arcconf";
        $adaptec_tool="$tools_dir/arcconf";
      }
      if (! -e "$adaptec_command") {
        system("chmod +x $adaptec_command");
      }
      if ($release_test=~/release 5/) {
          $adaptec_no="1";  
          @adaptec_info=`cd /tmp ; $adaptec_command GETCONFIG $adaptec_no`;
          process_adaptec_info($release_test);
      }
      else {
        for ($counter=0; $counter<3; $counter++) {
          $adaptec_no=$counter;
          $adaptec_no++;
          if (-e "$adaptec_proc/$counter") {
            $adaptec_test=1;
            @adaptec_info=`$adaptec_command GETCONFIG $adaptec_no`;
          }
          else {
            $adaptec_test=0;
          }
          if ($adaptec_test eq 1) {
            process_adaptec_info($release_test);
          }
        }
      }
    }
    # Check for IPS (ServeRAID)
    if ((-e "$ips_string/0")||(-e "$ips_string/1")||(-e "$ips_string/2")) {
      $command="grep 'Controller Type' |cut -f2 -d':' |awk '{print \$2}'";
      for ($counter=0; $counter<3 ; $counter++) {
        $serveraid_no=$counter;
        $serveraid_no++;
        if (-e "$ips_string/$counter") {
          $ibmraid_test=`cat $ips_string/$counter |$command`;
          chomp($ibmraid_test);
          $ibmraid_test=~s/ //g;
          $ibmraid_test=~tr/A-Z/a-z/;
          # Check which version of ServeRAID we have
          if ($ibmraid_test=~/4lx/) {
            $command="grep 'BIOS' |cut -f2 -d':' |awk '{print \$1}'";
            $ibmraid_test=`cat $ips_string/$counter |$command`;
            chomp($ibmraid_test);
            $ibmraid_test=~s/ //g;
            if ($ibmraid_test=~/^7/) {
              $ibmraid_test="7k";
            }
            else {
              $ibmraid_test="4lx";
            }
          }
          if ($ibmraid_test=~/5i/) {
            $firmware_command="grep 'Firmware Version' |cut -f2 -d':' |awk '{print \$1}'";
            $firmware_test=`cat $ips_string/$counter |$firmware_command`;
            if ($firmware_test=~/7\.12/) {
              $ibmraid_test="712";
            }
          }
          $ibmraid_command="/usr/local/bin/ipssend";
          $ibmraid_command="$ibmraid_command$ibmraid_test";
          if (! -e "$ibmraid_command") {
            $ibmraid_tool="$tools_dir/ipssend$ibmraid_test";
            system("chmod +x $ibmraid_command");
          }
          if (-e "$ibmraid_command") {
            $ibmraid_test=1;
            if ($serveraid_no gt 2) {
              $command="$ibmraid_command getconfig 1";
            }
            else {
              $command="$ibmraid_command getconfig $serveraid_no";
            }
            @ibmraid_info=`$command`;
          }
          else {
            $ibmraid_test=0;
          }
          if ($ibmraid_test eq 1) {
            process_ibmraid_info();
          }
        }
      }
    }
    # Check for Software Mirroring
    if (-e "/proc/mdstat") {
      $swmirror_test=`cat /proc/mdstat |grep active`;
      chomp($swmirror_test);
      if ($swmirror_test=~/active/) {
        $swmirror_test=1;
        @swmirror_info=`cat /proc/mdstat`;
      }
      else {
        $swmirror_test=0;
      }
      if ($swmirror_test eq 1) {
        process_swmirror_info();
      }
    }
    # Check for Dynapath
    if (-e "/usr/local/dynapath") {
      $dynapath_test=1;
      @dynapath_info=`$dynapath_command status`;
      process_dynapath_info();
    }
    # Check for LSI 
    if ((-e "/proc/mpt/ioc0/summary")||(-e "/sys/module/mptsas/version")||(-e "/proc/scsi/mptsas/7")) {
      if (-e "/proc/mpt/ioc0/summary") {
        $lsi_test=`cat /proc/mpt/ioc0/summary |grep LSI`;
        chomp($lsi_test);
      }
      else {
        if (-e "/sys/module/mptsas/version") {
          $lsi_test="LSI";
        }
        else {
          if (-e "/proc/scsi/mptsas/7") {
            $lsi_test=`cat /proc/scsi/mptsas/7 |grep LSI`;
            chomp($lsi_test);
          }
        }
      }
      if ($lsi_test=~/LSI/) {
        $module_test=`/sbin/lsmod |grep mptctl`;
        chomp($module_test);
        if ($module_test!~/mptctl/) {
          system("modprobe mptctl");
        }
        if ($lsi_test=~/SAS106[4,8]/) {
          $lsi_command="/usr/local/bin/cfg1064";
          $tools_file="$tools_dir/cfg1064";
          $command="$lsi_command 0 DISPLAY";
        }
        else {
          $lsi_command="/usr/local/bin/cfg1030";
          $tools_file="$tools_dir/cfg1030";
          $command="$lsi_command getstatus 1";
        }
        if (! -e "$lsi_command") {
          get_ftp_file($tools_file,$lsi_command);
          system("chmod +x $lsi_command");
        }
        if (-e "$lsi_command") {
          $lsi_test=1;
          @lsi_info=`$command`;
        }
        else {
          $lsi_test=0;
        }
        if ($lsi_test eq 1) {
          process_lsi_info();
        }
      }
    }
  }
  else {
    # Check if we are running FreeBSD 
    if ($os_version=~/FreeBSD/) {
      $freebsd_command="/usr/dpt/raidutil";
      if (-e "$freebsd_command") {
        $freebsd_test=1;
        @freebsd_info=`$freebsd_command  -d 0 -L physical`;
      }
      else {
        $freebsd_test=0;
      }
      if ($freebsd_test eq 1) {
        process_freebsd_info();
      }
      $lsi_command="/usr/local/bin/ipmitool";
      if (-e "$lsi_command") {
        $lsi_test=`/sbin/kldstat |grep ipmi`;
        chomp($lsi_test);
        if ($lsi_test!~/ipmi/) {
          system("/sbin/kldload ipmi");
        }
        $lsi_test=1;
        @lsi_info=`$lsi_command sdr list |grep 'io.hdd' |awk -F '|' '{print \$1":"\$3}'`;
      }
      if ($lsi_test eq 1) {
        process_lsi_info();
      }
    }
    else {
      # If we don't have FreeBSD or Linux, then assume Solaris
      if ($os_version=~/5\.8|5\.9|5\.10/) {
        # Find location of SDS command
        $sds_command="/usr/sbin/metastat";
        if (! -e "$sds_command") {
          $sds_command="/usr/opt/SUNWmd/sbin/metastat";
        }
        $platform_test=`uname -i`;
        if ($platform_test=~/i86pc/) {
          $platform_test=`/usr/sbin/prtdiag -v |head -1`;
        }
        chomp($platform_test);
        if ($platform_test=~/V440|V20z|V40z|T200|V445|V245|X4100|X4200|X4600|T5220|T5120|T6220|T6300|T6320|T6340/) {
          $raidctl_test=`cat /etc/vfstab |grep md`;
          chomp($raidctl_test);
          $ufs_test=`cat /etc/vfstab |grep ufs`;  
          chomp($ufs_test);
          $raidctl_version=`ls -l /usr/sbin/raidctl`;
          chomp($raidctl_version);
          if (($raidctl_test=~/md/)||($ufs_test!~/ufs/)) {
            $raidctl_test=0;
          }
          else {
            $raidctl_test=1;
            # Special handling for Solaris 10
            if ($os_version=~/10/) {
              # Handling for Update 4 and above
              $release_test=`cat /etc/release |head -1`;
              chomp($release_test);
              ($prefix,$release_test)=split('/',$release_test);
              ($release_test,$suffix)=split(' ',$release_test);
              $release_test=~s/0//g;
              if (($release_test ge 7)||($raidctl_version=~/2008/)) {
                if ($os_version=~/sparc/) {
                  if ($platform_test=~/T5220/) {
                    $controller_no="c1";
                  }
                  else {
                    $controller_no="c0";
                  }
                }
                else {
                  if ($platform_test=~/X4100/) {
                    $controller_no="c2";
                  }
                  else {
                    if ($platform_test=~/X4600/) {
                      $controller_no="c1";
                    }
                    else {
                      $controller_no="c3";
                    } 
                  }
                }
                if (-e "$raidctl_output") {
                  system("rm $raidctl_output");
                  system("touch $raidctl_output");
                }
                # search through cfgadm ouput to get controller numbers
                $raidctl_command="for i in `cfgadm -al |grep '^$controller_no' |awk '{print  \$1}' |grep dsk |cut -f2 -d'/'` ; do raidctl -l \$i >> $raidctl_output 2>&1 ; done";
              }
              else {
                $raidctl_command="/usr/sbin/raidctl > $raidctl_output";
              }
            }
            else {
              $raidctl_command="/usr/sbin/raidctl > $raidctl_output";
            }
            system("$raidctl_command");
            if (-e "$raidctl_output") {
              @raidctl_info=`cat $raidctl_output |egrep '0|-'`;
#             system("rm $raidctl_output");
            }
          }
          if ($raidctl_test eq 1) {
            process_raidctl_info($controller_no);
          }
        }
      }
      else {
        $sds_command="/usr/opt/SUNWmd/sbin/metastat";
      }
      # Check to see if we have any SDS file systems
      $sds_test=`cat /etc/vfstab |grep -v '^#' |grep md`;
      chomp($sds_test);
      if ($sds_test=~/md/) {
        @sds_info=`$sds_command`;
        $sds_test=@sds_info[0];
        if ($sds_test=~/there are no existing databases|No such file or directory/) {
          $sds_test=0;
        }
        else {
          $sds_test=1;
        }
        if ($sds_test eq 1) {
          process_sds_info();
        }
      }
      # Check to see if we have ZFS mirrors
      $zfs_command="/usr/sbin/zpool";
      if (-e "$zfs_command") {
        $zfs_test=1;
        @zpool_list=`$zfs_command status |grep 'pool:' |awk '{print \$2}'`;
        foreach $zpool_name (@zpool_list) {
          chomp($zpool_name);
          @zfs_info=`$zfs_command status $zpool_name |awk '{print \$1" "\$2}'`;
          process_zfs_info();
        }
      }
      # Check if veritas is installed
      $veritas_command="/usr/sbin/vxdisk";
      if (-e "$veritas_command") {
        $veritas_test=1;
        @veritas_info=`$veritas_command list`;
        process_veritas_info();
      }
    }
  }
  return;
}

# mail and trouble ticket option

if ($option{'m'}) {
  $mail_report=1;
}

# test mode, pretend there are errors

if ($option{'t'}) {
  $errors=1;
}

# help

if ($option{'h'}) {
  print_usage();
  exit;
}

# version information

if ($option{'V'}) {
  print_version();
  exit;
}

# print change log

if ($option{'c'}) {
  print_change_log();
  exit;
}

# monitor_user option, runs without network

if ($option{'P'}) {
  $option{'n'}=1;
}

if (($option{'F'})||($option{'A'})) {
  $option{'f'}=1;
}

# if running in a correct mode actually do disk checks

if (($option{'m'})||($option{'l'})||($option{'t'})||($option{'n'})||($option{'f'})) {
  if (!$option{'n'}) {
    check_version_stub();
  }
  if ($option{'l'}) {
    print "\n";
  }
  check_local_config();
  if (!$option{'P'}) {
    get_messages_info();
  }
  process_disk_info();
  if ($option{'l'}) {
    print "\n";
  }
  exit;
}

# Print version information

sub print_version {
  print "\n";
  print "$script_info v. $version_info [$packager_info]\n";
  print "\n";
  return;
}

# Print help information

sub print_usage {
  print_version();
  print "Usage: $0 [OPTIONS]\n"; 
  print "-h: Display help\n";
  print "-V: Display version information\n";
  print "-l: Display list of mirrored disks\n";
  print "-f: Display warning messages if any (during this hour)\n";
  print "-F: Display warning messages if any (during this day)\n";
  print "-A: Display warning messages if any\n";
  print "-m: If an error is found send email\n";
  print "-s: If an error is found create syslog message\n";
  print "-t: Induce false errors (for testing purposes)\n";
  print "-n: Run in non network mode (no check for updates)\n";
  print "-P: Print error codes for Patrol\n";
  print "-v: Verbose output\n";
  return;
}

# Routine to get information from script header

sub search_script {
  my $search_string=$_[0];
  my $result;
  my $header;
  if ($script_file[0]!~/perl/) {
    @script_file=read_a_file($script_name);
  }
  my @search_info=grep{/^# $search_string/}@script_file;
  ($header,$result)=split(":",$search_info[0]);
  $result=~s/^\s+//;
  chomp($result);
  return($result);
}

# Print version information

sub print_version {
  print "\n";
  print "$script_info v. $version_info [$packager_info]\n";
  print "\n";
  return;
}

# Add to bad disk list

sub add_to_bad_disk_list {
  my $disk_name=$_[0]; 
  my $disk_status=$_[1]; 
  my $file_system=$_[2];
  my $record; 
  my $tester=0; 
  my $suffix;
  if ($disk_name=~/\(/) {
    ($disk_name,$suffix)=split(" ",$disk_name);
  } 
  if ($os_version=~/Sun/) {
    if ($disk_name=~/dev/) {
      $disk_name=~s/\/dev\/dsk\///g;
    }
  }
  if ($disk_name!~/[0-9]$|[a-g]$/) {
    return;
  } 
  foreach $record (@bad_disk_list) {
    if ($record=~/^$disk_name/) {
      $tester=1;
    }
    if ($record=~/$file_system/) {
      $tester=1;
    }
  }
  if ($tester eq 0) {
    push(@bad_disk_list,"$disk_name|$disk_status|$file_system");
  }
  return;
}

# Process LSI SASx36 Information

sub process_sasx36_info {
  my $sasx36_command="/opt/MegaRAID/MegaCli/MegaCli64";
  my $sasx36_rpm_1="$tools_dir/MegaCli-8.00.16-1.i386.rpm";
  my $sasx36_rpm_2="$tools_dir/Lib_Utils-1.00-07.noarch.rpm";
  my $sasx36_rpm_3="$tools_dir/Lib_Utils2-1.00-01.noarch.rpm";
  my $sasx36_rpm_4="$tools_dir/MSM_linux_installer-8.00-05.tar.gz";
  my $sasx36_rpm_5="$tools_dir/libstdc++33-3.3.3-11.9.x86_64.rpm";
  my $sasx36_rpm_6="$tools_dir/libgcc43-32bit-4.3.4_20091019-0.7.35.x86_64.rpm";
  my $sasx36_rpm_7="$tools_dir/libstdc++43-32bit-4.3.4_20091019-0.7.35.x86_64.rpm";
  my $sasx36_init="/etc/init.d/mrmonitor";
  my $record; 
  my $disk_group=0; 
  my $suffix; 
  my $disk_name; 
  my $disk_status;
  my $file_system; 
  my $manual_mount; 
  my $mirror_type;
  my $prefix; 
  my $spans; 
  my $spans_no; 
  my $final_spans=0;
  my $spans_status_1; 
  my $spans_status_2;
  my $model="MR9261-8i";
  if (! -e "/usr/lib/libstdc++.so.5") {
    if (-e "$sasx36_rpm_6") {
      system("rpm -i $sasx36_rpm_6");
    }
    if (-e "$sasx36_rpm_5") {
      system("rpm -i $sasx36_rpm_5");
    }
  }
  if (! -e "/usr/lib/libstdc++.so.6") {
    if (-e "$sasx36_rpm_7") {
      system("rpm -i $sasx36_rpm_7");
    }
  } 
  if (! -e "$sasx36_command") {
    if (-e "$sasx36_rpm_2") {
      system("rpm -i $sasx36_rpm_2");
    }
    if (-e "$sasx36_rpm_3") {
      system("rpm -i $sasx36_rpm_3");
    }
    if (-e "$sasx36_rpm_1") {
      system("rpm -i $sasx36_rpm_1");
    }
  }
  if (! -e "$sasx36_init") {
    if (-e "$sasx36_rpm_4") {
      system("tar -xpf $sasx36_rpm_4");
      system("cd /tmp/disk ; ./RunRPM.sh");
      system("cd /tmp");
      system("rm -rf /tmp/disk");
    }
  }
  @sasx36_info=`$sasx36_command -CfgDsply -aAll`;
  foreach $record (@sasx36_info) {
    chomp($record);
    if ($record=~/^DISK GROUPS/) {
      ($prefix,$disk_group)=split(":",$record);
      $disk_group=~s/ //g;
      $disk_name=search_device_list($model,$disk_group);  
      #$disk_name=chr($disk_group+97);
      #$disk_name="sd$disk_name";
      ($file_system,$manual_mount)=get_file_system($disk_name,$mirror_type);
    }
    if ($record=~/Number of Spans/) {
      ($prefix,$spans)=split(":",$record);
      $spans=~s/ //g;
    }
    if ($record=~/SPAN/) {
      ($prefix,$spans_no)=split(":",$record);
      $spans_no=~s/ //g;
      $final_spans=0; 
    }
    if ($record=~/^State/) {
      if (($spans=~/2/)&&($spans_no=~/0/)) {
        ($prefix,$spans_status_1)=split(":",$record);
        $spans_status_1=~s/^ //g;
      }
      if (($spans=~/1/)&&($spans_no=~/0/)) {
        $final_spans=1; 
        ($prefix,$disk_status)=split(":",$record);
        $disk_status=~s/^ //g;
      }
      if (($spans=~/2/)&&($spans_no=~/1/)) {
        $final_spans=1; 
        ($prefix,$spans_status_2)=split(":",$record);
        $spans_status_2=~s/^ //g;
        if (($spans_status_1!~/OK|Optimal/)||($spans_status_2!~/OK|Optimal/)) {
          $disk_status="Error";
        }
        else {
          $disk_status=$spans_status_1;
        }
      }
      if ($final_spans eq 1){
        $disk_status=~s/Optimal/OK/g;
        if ($verbose eq 1) {
          print "Disk:  $disk_name\n";
          print "Status:  $disk_status\n";
          print "Mount: $file_system\n";
        }
        if ($disk_status!~/OK/) {
          add_to_bad_disk_list($disk_name,$disk_status,$file_system);
        }
      }
    }
  }
  return;
} 

# Process PERC H7000 Information

sub process_h700_info {
  my $h700_command="/opt/MegaRAID/MegaCli/MegaCli64";
  my $h700_rpm="MegaCli-1.01.39-0.i386.rpm";
  my $local_file="$tools_dir/$h700_rpm"; 
  my $record;
  my $disk_group=0; 
  my $suffix; 
  my $disk_name; 
  my $disk_status;
  my $file_system; 
  my $manual_mount; 
  my $mirror_type;
  my $prefix; 
  my $spans; 
  my $spans_no; 
  my $final_spans=0;
  my $spans_status_1;
  my $spans_status_2;
  my $model="H700";
  if (! -e "$h700_command") {
    if (-e "$local_file") {
      system("rpm -i $local_file");
      system("rm -f $local_file");
    }
  }
  @h700_info=`$h700_command -CfgDsply -aAll`;
  foreach $record (@h700_info) {
    chomp($record);
    if ($record=~/^DISK GROUPS/) {
      ($prefix,$disk_group)=split(":",$record);
      $disk_group=~s/ //g;
      $disk_name=search_device_list($model,$disk_group);  
      #$disk_name=chr($disk_group+97);
      #$disk_name="sd$disk_name";
      ($file_system,$manual_mount)=get_file_system($disk_name,$mirror_type);
    }
    if ($record=~/Number of Spans/) {
      ($prefix,$spans)=split(":",$record);
      $spans=~s/ //g;
    }
    if ($record=~/SPAN/) {
      ($prefix,$spans_no)=split(":",$record);
      $spans_no=~s/ //g;
      $final_spans=0; 
    }
    if ($record=~/^State/) {
      if (($spans=~/2/)&&($spans_no=~/0/)) {
        ($prefix,$spans_status_1)=split(":",$record);
        $spans_status_1=~s/ //g;
      }
      if (($spans=~/1/)&&($spans_no=~/0/)) {
        $final_spans=1; 
        ($prefix,$disk_status)=split(":",$record);
        $disk_status=~s/ //g;
      }
      if (($spans=~/2/)&&($spans_no=~/1/)) {
        $final_spans=1; 
        ($prefix,$spans_status_2)=split(":",$record);
        $spans_status_2=~s/ //g;
        if (($spans_status_1!~/OK|Optimal/)||($spans_status_1!~/OK|Optimal/)) {
          $disk_status="Error";
        }
      }
      if ($final_spans eq 1){
        $disk_status=~s/Optimal/OK/g;
        if ($verbose eq 1) {
          print "Disk:  $disk_name\n";
          print "Status:  $disk_status\n";
          print "Mount: $file_system\n";
        }
        if ($disk_status!~/OK|Optimal/) {
          add_to_bad_disk_list($disk_name,$disk_status,$file_system);
        }
      }
    }
  }
  return;
} 

# Process Dynapath information

sub process_dynapath_info {
  my $record; 
  my $suffix; 
  my $prefix;
  my $disk_name; 
  my $disk_status; 
  my $file_system;
  my $manual_mount; 
  my $mirror_type; 
  my $disk_temp;
  foreach $record (@dynapath_info) {
    chomp($record);
    if ($record=~/sd/) {
      $disk_name="";
      if (($record!~/available/)||($errors eq 1)) {
        $disk_status="ERROR";
      }
      else {
        $disk_status="OK";
      }
      ($prefix,$disk_name)=split("::",$record);
      $disk_name=substr($disk_name,1,3);  
      if ($disk_name=~/[a-z]/) {
        $disk_name=get_dynapath_device($disk_name);
        $disk_name=~s/ //g;
        ($file_system,$manual_mount)=get_file_system($disk_name,$mirror_type);
        if ($disk_temp!~/$disk_name/) {
          $disk_status=~s/Optimal/OK/g;
          if ($verbose eq 1) {
            print "Disk:  $disk_name\n";
            print "Status:  $disk_status\n";
            print "Mount: $file_system\n";
          }
          if ($disk_status=~/ERROR/) {
            add_to_bad_disk_list($disk_name,$disk_status,$file_system);
          }
          $disk_temp="$disk_temp,$disk_name";
        }
      }
    }
  }
  return;
}

# Process Veritas Information

sub process_veritas_info {
  my $record; 
  my $disk_name; 
  my $suffix;
  my $file_system; 
  my $group_name; 
  my $disk_status;
  foreach $record (@veritas_info) {
    chomp($record);
    if ($record=~/^c|^Di/) {
      ($disk_name,$suffix,$file_system,$group_name,$disk_status)=split(' ',$record);
      $disk_status=~s/Optimal/OK/g;
      if ($errors eq 1) {
        $disk_status="ERROR";
      }
      if ($verbose eq 1) {
        print "Disk:    $disk_name\n";
        print "Status:  $disk_status\n";
        print "VM info: $group_name\:$file_system\n";
      }
      if ($disk_status=~/fail/) {
        add_to_bad_disk_list($disk_name,$disk_status,$file_system);
      }
    }
  }
  return;
}

# Process ZFS mirrors

sub process_zfs_info {
  my $pool_name=""; 
  my $record; 
  my $suffix;
  my $pool_test=0; 
  my $mirror_test=1; 
  my $disk_name; 
  my $disk_status; 
  my $file_system; 
  my @fs_list;
  my $tester=0; 
  my $number; 
  my $temp_name; 
  my $prefix; 
  my $fail_name; 
  my @disk_list;
  my $number;
  my $disk_record; 
  my $disk_type;
  my $mirror_check=0;
  foreach $record (@zfs_info) {
    chomp($record);
    if ($record=~/pool\:/) {
      ($prefix,$pool_name)=split(": ",$record);
      chomp($pool_name);
      @disk_list=`/usr/sbin/zpool status $pool_name |awk '{print \$1" "\$2}' |egrep '^mirror|^c[0-2]'`;
      if ($disk_list[0]=~/mirror/) {
        $mirror_check=1;
      } 
      if (($disk_list[0]=~/c[0-9]/)||($disk_list[1]=~/c[0-9]/)) {
        for ($number=0; $number<@disk_list; $number++) {
          $disk_record=$disk_list[$number];
          if ($disk_record!~/mirror/) {
            ($temp_name,$disk_status)=split(" ",$disk_record);
            $temp_name=~s/ //g;
            if ($disk_name=~/[A-z]/) {
              if ($disk_name!~/$temp_name/) {
                $disk_name="$disk_name,$temp_name";
              }
            }
            else {
              $disk_name=$temp_name;
            }
          }
        }
        if ($errors eq 1) {
          $disk_status="ERROR";
          $fail_name=$temp_name;
        }
        else {
          if ($disk_record=~/ONLINE/) {
            $disk_status="OK";
          }
          else {
            $disk_status="ERROR";
            $fail_name=$temp_name;
          }
        }
        if ($os_version=~/T1000/) {
          $disk_type=`iostat -E |grep ATA`;
          chomp($disk_type);  
        }
        if (($disk_list[2]!~/c/)&&($disk_type!~/ATA/)&&($mirror_check eq 1)) {
          $mirror_test=0;
          $disk_status="UNMIRRORED";
          $fail_name=$temp_name;
        }
        $file_system=get_zfs_file_system($pool_name);
        $file_system=~s/legacy,//g;
        $file_system=~s/none,//g;
        $file_system=~s/-,//g;
        $disk_name=~s/pool:,//g;
        $disk_status=~s/Optimal/OK/g;
        if ($verbose eq 1) {
          print "Pool:    $pool_name\n";
          print "Disks:   $disk_name\n";
          print "Status:  $disk_status\n";
          print "Mount:   $file_system\n";
        }
        if (($disk_status!~/OK/)||($mirror_test eq 0)) {
          add_to_bad_disk_list($fail_name,$disk_status,$file_system);
        }
      }
    }
    
  }
  return;
} 

# Get zpool name

sub get_zpool_name {
  my $disk_name=$_[0]; 
  my $tester; 
  my $record;
  my @zpool_list=`zpool list |grep -v '^NAME' |awk '{print \$1}'`;
  my $zpool_name="";
  $disk_name=~s/\/dev\/dsk\///g;
  foreach $record (@zpool_list) {
    chomp($record);
    if ($record=~/[A-z]/) {
      $tester=`zpool status |grep '$disk_name'`;
      chomp($tester);
      if ($tester=~/$disk_name/) {  
        $zpool_name=$record;
      }
    }
  }
  return($zpool_name);
}

# Get ZFS filesystem

sub get_zfs_file_system {

  my $pool_name=$_[0]; 
  my $file_system; 
  my $tester=0;
  my $suffix;
  my $prefix; 
  my $number;
  for ($number=0; $number<@fs_list; $number++) {
    $suffix=$fs_list[$number];
    chomp($suffix);
    ($prefix,$suffix)=split(" ",$suffix);
    $suffix=~s/\ //g;
    if ($prefix=~/dump/) {
      $suffix="dump";
    }
    if ($prefix=~/swap/) {
      $suffix="swap";
    }
    if ($tester eq 0) {
      $file_system=$suffix;
      $tester=1;
    }
    else {
      if ($file_system!~/$suffix/) {
        $file_system="$file_system,$suffix";
      }
    }
  }
  return($file_system);
}

# Process raidctl output

sub process_raidctl_info {
  my $controller_no=$_[0]; 
  my $record; 
  my $rddiff=0; 
  my $disk_name; 
  my $raid_type; 
  my $column; 
  my $disk_status; 
  my $raidctl_disk1; 
  my $raidctl_status1; 
  my $suffix; 
  my $file_system; 
  my $raidctl_disk2; 
  my $raidctl_status2;
  my $number; 
  my $tester=0; 
  my $raidctl_count=0; 
  my $disk_size;
  my $temp_one; 
  my $temp_two; 
  my $temp_three; 
  my $stripe_size;
  my $zfs_command; 
  my $zpool_name;
  foreach $record (@raidctl_info) {
    chomp($record);
    $record=~s/GOOD/OK/g;
    if ($record=~/Type|IM/) {
      $rddiff=1;
    }
    if ($record=~/c|0\.|MISSING/) {
      if ($record=~/^c/) {  
        $raidctl_count=0;
        if ($rddiff eq 1) {
          $record=~s/IM//g;
        }
        $record=~s/\t\t/:/g;
        $record=~s/\t/:/g;
        if ($record=~/RAID1/) {
          $raidctl_count=1;
          if ($record=~/::/) {
            ($disk_name,$suffix,$disk_size,$stripe_size,$column,$raid_type)=split(":",$record);
          }
          else {
            ($disk_name,$column)=split(":",$record);
          }
          if ($column=~/OPT|OK|GOOD/) {
            $disk_status="OK";
          }
          else {
            $disk_status="ERROR";
          }
        }
        else {  
          ($disk_name,$disk_status,$raidctl_disk1,$raidctl_status1)=split(":",$record);
          if ($disk_status=~/OPT|OK|GOOD/) {
            $disk_status="OK";
          }
          else {
            $disk_status="ERROR";
          }
        }
        if ($disk_name=~/OK|IM/) {
          $disk_name=~s/OK//g;
          $disk_name=~s/IM//g;
          $disk_name=~s/ //g;
        }
        @fs_list=`grep '$disk_name' /etc/vfstab |grep -v '^#' |awk '{print \$3}' |sed 's/^-/swap/g'`;
        $file_system="";
        $disk_status=~s/^\ //g;
        $tester=0;
        if (($fs_list[0]!~/[A-z]/)||($fs_list[1]!~/[A-z]/)) {
          $zfs_command="/usr/sbin/zfs";
          if (-e "$zfs_command") {
            $zpool_name="";
            $zpool_name=get_zpool_name($disk_name);
            if ($zpool_name=~/[A-z]/) {
              $file_system=get_zfs_file_system($zpool_name);
            }
          }
        }
        else {
          for ($number=0; $number<@fs_list; $number++) {
            $suffix=$fs_list[$number];
            chomp($suffix);
            $suffix=~s/\ //g;
            if ($tester eq 0) {
              $file_system=$suffix;
              $tester=1;
            }
            else {
              if ($file_system!~/$suffix/) {
                $file_system="$file_system,$suffix";
              }
            }
          }
        }
      }
      else {
        while ($record=~/^\t/) {
          $record=~s/^\t//g;
        }
        $record=~s/\t\t/:/g;
        if ($record=~/0\./) {
          if ($raidctl_count eq 1) {
            ($raidctl_disk1,$raidctl_status1)=split(":",$record);
            ($raidctl_disk1,$suffix)=split(' ',$raidctl_disk1);
            ($temp_one,$temp_two,$temp_three)=split('\.',$raidctl_disk1);
            $raidctl_disk1="$controller_no t$temp_two d$temp_three";
            $raidctl_disk1=~s/ //g;
            $raidctl_status1=~s/\t//g;
            $raidctl_count++;
          }
          else {
            ($raidctl_disk2,$raidctl_status2)=split(":",$record);
            ($raidctl_disk2,$suffix)=split(' ',$raidctl_disk2);
            ($temp_one,$temp_two,$temp_three)=split('\.',$raidctl_disk2);
            $raidctl_disk2="$controller_no t$temp_two d$temp_three";
            $raidctl_disk2=~s/ //g;
            $raidctl_status2=~s/\t//g;
            if ($verbose eq 1) {
              print "Disk:   $disk_name ($raidctl_disk1,$raidctl_disk2)\n";
              print "Status: $disk_status ($raidctl_status1,$raidctl_status2)\n";
              print "Mount:  $file_system\n";
            }
            if ($errors eq 1) {
              $disk_status="ERROR";
            }
            if (($disk_status!~/OK/)||($raidctl_status1!~/OK/)||($raidctl_status2!~/OK/)) {
              $disk_name="$disk_name ($raidctl_disk1,$raidctl_disk2)";
              $disk_status="$disk_status ($raidctl_status1,$raidctl_status2)";
              add_to_bad_disk_list($disk_name,$disk_status,$file_system);
            }
          }
        }
        else {
          ($raidctl_disk2,$raidctl_status2)=split(":",$record);
          if ($errors eq 1) {
            $disk_status="ERROR";
          }
          if ($verbose eq 1) {
            print "Disk:   $disk_name ($raidctl_disk1,$raidctl_disk2)\n";
            print "Status: $disk_status ($raidctl_status1,$raidctl_status2)\n";
            print "Mount:  $file_system\n";
          }
          if (($disk_status!~/OK/)||($raidctl_status1!~/OK/)||($raidctl_status2!~/OK/)) {
            $disk_name="$disk_name ($raidctl_disk1,$raidctl_disk2)";
            $disk_status="$disk_status ($raidctl_status1,$raidctl_status2)";
            add_to_bad_disk_list($disk_name,$disk_status,$file_system);
          }
        }
      }
    }
  }
  return;
}

# Process meta information

sub process_sds_info {
  my $counter; 
  my $record; 
  my $submirror_counter; 
  my $submirror_test;
  my $mirror_test; 
  my $submirror_temp; 
  my $disk_status; 
  my $disk_name;
  my $detached_test; 
  my $temp_name; 
  my $suffix; 
  my $number;
  my $resync_text; 
  my $prefix; 
  my $exists; 
  my $resync_string;
  my $submirror_name; 
  my $resync_counter; 
  my $tester=0;
  my $temp_record; 
  my $temp_counter;
  for ($counter=0; $counter<@sds_info; $counter++) {
    $record=$sds_info[$counter];
    chomp($record);
    $record=~s/Okay/OK/g;
    if ($record=~/^d[0-9]/) {
      if ($submirror_counter eq 2) {
        ($prefix,$submirror_temp)=split(/\:/,$record);
        ($prefix,$submirror_temp)=split('of',$submirror_temp);
        $submirror_temp=~s/ //g;
      }
      if ($record!~/Submirror/) {
        if ($record=~/Mirror/) {
          if ($submirror_counter eq 1) {
            $submirror_test=1;
            if (($submirror_test eq 1)&&($mirror_test eq 1)&&($submirror_counter eq 1)) {
              if ($verbose eq 1) {
                print "Status:  Incomplete Mirror\n";
              }
              $detached_test=1;
            }
          } 
          else {
            $submirror_test=0;
          }
          $mirror_test=1;
          $submirror_counter=2;
        }
        else {
          $mirror_test=0;
          $submirror_counter=0;
        }
        ($disk_name,$suffix)=split(/\:/,$record);
        $disk_name=~s/ //g;
        $tester=1;
        if ($verbose eq 1) {
          print "Disk:    $disk_name\n";
        }
      }
      else {
        ($submirror_name,$suffix)=split(/\:/,$record);
        $submirror_name=~s/ //g;
        if ($verbose eq 1) {
          print "Subdisk: $submirror_name\n";
        }
        #$submirror_counter--;
        if ($submirror_counter gt 0) {
          $submirror_counter--;
        }
      }
    }
    if ($tester eq 1) {
      # Check for State of mirror
      # Extract resync status if appropriate
      if ($record=~/State\:/) {
        if ($verbose eq 1) {
          ($prefix,$disk_status)=split(/\:/,$record);
          $disk_status=~s/^\ //g;
          if ($disk_status=~/Resync/) {
            $resync_counter=$counter;
            $resync_counter=$resync_counter+3;
            $resync_string=$sds_info[$resync_counter];
            chomp($resync_string);
            if ($resync_string=~/progress/) {
              ($prefix,$resync_string)=split(':',$resync_string);
              $resync_string=~s/ //g;
              $resync_string=~s/[A-z]//g;
              $resync_text="$disk_status [$resync_string]";
            }
          }
          if ($disk_status=~/Resync|Error|Offline|maintenance/) {
            if ($disk_status=~/Resync/) {
              $temp_counter=$counter;
              $temp_counter++;
              $temp_record=$sds_info[$temp_counter];
              if ($temp_record=~/Submirror/) {
                print "Status:  $resync_text\n";
              }
            }
            else {  
              print "Status:  $disk_status\n";
            }
          }
        }
        if (($record!~/OK/)||($errors eq 1)||($detached_test eq 1)||($disk_status=~/Resync/)) {
          ($prefix,$disk_status)=split(/\:/,$record);
          $disk_status=~s/^\ //g;
          if ($detached_test eq 1) {
            $file_system=`grep '$submirror_temp' /etc/vfstab |grep -v '#' |grep md |grep -v '$submirror_temp\[0-9\]' |awk '{print \$3}'`;
          }
          else {
            $file_system=`grep '$disk_name' /etc/vfstab |grep -v '#' |grep md |grep -v '$disk_name\[0-9\]' |awk '{print \$3}'`;
          }
          chomp($file_system);
          $file_system=~s/ //g;
          if ($file_system!~/\//) {
            $file_system="swap";
          }
          for ($number=0; $number<@bad_disk_list; $number++) {
            $temp_name=$bad_disk_list[$number];
            ($temp_name,$suffix,$suffix)=split(/\|/,$temp_name);
            if ($temp_name=~/^$disk_name$/) {
              $exists=1;
              $detached_test=0;
            }
          }
          if ($exists eq 0) {
            if ($disk_name=~/^d/) {
              if ($errors eq 1) {
                $disk_status="ERROR";
                add_to_bad_disk_list($disk_name,$disk_status,$file_system);
              }
              if ($detached_test eq 1) {
                $disk_status="INCOMPLETE";
                $detached_test=0;
                add_to_bad_disk_list($submirror_temp,$disk_status,$file_system);
              }
              if ($disk_status=~/Resync|Error|Offline|maintenance/) {
                add_to_bad_disk_list($disk_name,$disk_status,$file_system);
              }
            }
            $marker++;
            $exists=0;
          }
          else {
            $exists=0;
          } 
        }
        if ($verbose eq 1) {
          $file_system=`grep '$disk_name' /etc/vfstab |grep -v '#' |grep md |grep -v '$disk_name\[0-9\]' |awk '{print \$3}'`;
          chomp($file_system);
          $file_system=~s/ //g;
          if ($file_system!~/\//) {
            $file_system="swap";
          }
          if ($submirror_counter le 0) {
            print "Mount:   $file_system\n";
          }
        }
        if ($submirror_counter le 0) {
          $tester=0;
        }
      } 
    }
  }
  return;
}

# Process DAC info

sub process_dac960_info {
  my $file_system="NA"; 
  my $record;
  my $disk_status; 
  my $tester=0; 
  my $prefix; 
  my $disk_name;
  my $suffix; 
  my $vendor; 
  my $models; 
  my $errors;
  foreach $record (@dac960_info) {
    chomp($record);
    if (($record=~/Vendor/)&&($record!~/ESG-SHV/)) {
      ($disk_name,$suffix,$vendor,$suffix,$models,$suffix,$suffix)=split(' ',$record);
    }
    if ($record=~/Disk Status/) {
      ($prefix,$prefix,$disk_status,$suffix,$suffix)=split(' ',$record);
      $disk_status=~s/\,//g;
      if ($errors eq 1) {
        $disk_status="ERROR";
      }
      if ($disk_status!~/Online|Standby|Hotspare/) {
        add_to_bad_disk_list($disk_name,$disk_status,$file_system);
      }
      $tester=1;
    }
    if ($tester eq 1) {
      if ($verbose eq 1) {
        print "Disk:   $disk_name\n";
        print "Status: $disk_status\n";
      }
      $tester=0;
    }
  }
  return;
}

# Process I20 info

sub process_i2o_info {
  my $file_system="NA"; 
  my $record;
  my $disk_target_id; 
  my $disk_channel; 
  my $disk_target; 
  my $disk_lun; 
  my $disk_name; 
  my $disk_status;
  foreach $record (@i2o_info) {
    chomp($record);
    if ($record=~/TID/) {
      $record=~s/\)//g;
      $record=~s/\(//g;
      ($disk_target_id,$disk_channel,$disk_target,$disk_lun,$disk_status)=split(' ',$record);
      $disk_name="$disk_target_id $disk_channel $disk_target $disk_lun";
      if ($errors eq 1) {
        $disk_status="ERROR";
      }
      if ($disk_status!~/online|standby/) {
        add_to_bad_disk_list($disk_name,$disk_status,$file_system);
      }
      if ($verbose eq 1) {
        print "Disk:   $disk_name\n";
        print "Status: $disk_status\n";
      }
      
    }
  }
  return;
}

# Process IBM ServeRAID info (excluding 8i)

sub process_ibmraid_info {
  my @file_list; 
  my $record; 
  my $prefix;
  my $suffix; 
  my $disk_name; 
  my $file_system; 
  my $device_name;
  my $tester=0; 
  my $disk_status; 
  my $number;
  foreach $record (@ibmraid_info) {
    chomp($record);
    if ($record=~/Logical drive number/) {
      $tester=1;
      if ($record=~/1/) {
        $device_name="sda";
      }
      if ($record=~/2/) {
        $device_name="sdb";
      }
    }
    else {
      $tester=0;
    }
    if ($tester eq 1) {
      $disk_name="";
      @file_list=`df |grep '$device_name' |awk '{print \$1":"\$6}' ; grep '$device_name' /etc/fstab |grep dev |awk '{print \$1":"\$2}'`;
      for ($number=0; $number<@file_list; $number++) {
        $record=$file_list[$number];
        chomp($record);
        ($prefix,$suffix)=split(/\:/,$record);
        if ($prefix=~/$device_name/) {
          if ($disk_name!~/[A-z]/) {
            $disk_name="$prefix";
            $file_system="$suffix";
          }
          else {
            if ($disk_name!~/$prefix/) {
              $disk_name="$disk_name,$prefix";
            }
            if ($file_system!~/$suffix/) {
              $file_system="$file_system,$suffix";
            }
          }
        }
      }
    }
    if ($record=~/Status of logical drive/) {
      if ($errors eq 1) {
        $disk_status="ERROR";
      }
      else {
        ($prefix,$disk_status)=split('\:',$record);
        $disk_status=~s/\ //g;
        $disk_status=~s/\(ONL\)//g;
        $disk_status=~s/\(OKY\)//g;
        $disk_status=~s/\(SBY\)//g;
        $disk_status=~s/\(HSP\)//g;
      }
      if ($disk_status!~/Online|Standby|Hotspare|Okay/) {
        add_to_bad_disk_list($disk_name,$disk_status,$file_system);
      }
      if ($verbose eq 1) {
        print "Disk:   $disk_name\n";
        print "Status: $disk_status\n";
        print "Mount:  $file_system\n";
      }
    }
  }
  return;
}

# Process linux software mirroring info

sub process_swmirror_info {
  my $resync_string=""; 
  my $resync_counter=0; 
  my $counter;
  my $record; 
  my $disk_name; 
  my $prefix; 
  my $disk_status;
  my $raid_no; 
  my $disk_one; 
  my $disk_two; 
  my $file_system;
  my $suffix;
  for ($counter=0; $counter<@swmirror_info; $counter++) {
    $record=$swmirror_info[$counter];
    chomp($record);
    if ($record=~/^md/) {
      ($disk_name,$prefix,$disk_status,$raid_no,$disk_one,$disk_two)=split(' ',$record);
    }
    if ($disk_status=~/active/) {
      $file_system=`grep '$disk_name' /etc/fstab |awk '{print \$2}'`;
      chomp($file_system);
      if ($record=~/blocks/) {
        if ($record=~/\_/) {
          $disk_status="ERROR";
          $resync_counter=$counter;
          $resync_counter++;
          $resync_string=$swmirror_info[$resync_counter];
          chomp($resync_string);
          if ($resync_string=~/recovery/) {
            ($prefix,$resync_string)=split('recovery = ',$resync_string);
            ($resync_string,$suffix)=split(' \(',$resync_string);
            $disk_status="ERROR [$resync_string]";
          }
        }
        else {
          $disk_status="OK";
        } 
        if ($disk_status=~/ERROR/) {
          add_to_bad_disk_list($disk_name,$disk_status,$file_system);
        }
        if ($verbose eq 1) {
          print "Disk:   $disk_name\n";
          print "Status: $disk_status\n";
          print "Mount:  $file_system\n";
        }
      }
    }
  }
  return;
}

# Process IBM Adaptec info (ServerRAID 8i)

sub process_adaptec_info {
  my $release_test=$_[0]; 
  my @file_list; 
  my $record; 
  my $prefix; 
  my $suffix; 
  my $disk_name; 
  my $file_system; 
  my $disk_status; 
  my $tester=0; 
  my $device_name; 
  my $number; 
  my $device_one="1"; 
  my $device_two="2"; 
  my $lvm_test;
  $lvm_test=`cat /etc/fstab |grep Vol |head -1`;
  chomp($lvm_test);
  if ($lvm_test=~/Vol/) {
    $lvm_test=1;
  }
  else {
    $lvm_test=0;
  }
  if ($release_test=~/release 5/) {
    $device_one="0";
    $device_two="1";
  }
  foreach $record (@adaptec_info) {
    chomp($record);
    if ($record=~/Logical drive number/) {
      $tester=1;
      if ($record=~/$device_one/) {
        if ($lvm_test eq 1) {
          $device_name="VolGroup00";
        }
        else {
          $device_name="sda";
        }
      }
      if ($record=~/$device_two/) {
        if ($lvm_test eq 1) {
          $device_name="VolGroup01";
        }
        else {
          $device_name="sdb";
        }
      }
    }
    else {
      $tester=0;
    }
    if ($tester eq 1) {
      $disk_name="";
      @file_list=`df |grep '$device_name' |awk '{print \$1":"\$6}' |grep -v mapper; grep '$device_name' /etc/fstab |grep dev|awk '{print \$1":"\$2}'`;
      for ($number=0; $number<@file_list; $number++) {
        $record=$file_list[$number];
        chomp($record);
        ($prefix,$suffix)=split(/\:/,$record);
        if ($prefix=~/$device_name/) {
          if ($disk_name!~/[A-z]/) {
            $disk_name="$prefix";
            $file_system="$suffix";
          }
          else {
            if ($disk_name!~/$prefix/) {
              $disk_name="$disk_name,$prefix";
            }
            if ($file_system!~/$suffix/) {
              $file_system="$file_system,$suffix";
            }
          }
        }
      }
    }   
    if ($record=~/Status of logical drive/) {
      ($prefix,$disk_status)=split(/\:/,$record);
      if ($errors eq 1) {
        $disk_status="ERROR";
      }
      else {
        if ($disk_status!~/Optimal|Okay/) {
          $disk_status=~s/Optimal/OK/g;
          add_to_bad_disk_list($disk_name,$disk_status,$file_system);
        }
        else {
          $disk_status="OK";
        }
      }
      if ($verbose eq 1) {
        print "Disk:   $disk_name\n";
        print "Status: $disk_status\n";
        print "Mount:  $file_system\n";
      }
    }
  }
  return;
}

# Process FreeBSD raidctl output

sub process_freebsd_info {
  my $file_system="N/A"; 
  my $record;
  my $disk_name; 
  my $suffix; 
  my $disk_status; 
  my $file_system;
  foreach $record (@freebsd_info) {
    chomp($record);
    if ($record=~/DASD/) {
      ($disk_name,$suffix,$suffix,$suffix,$suffix,$suffix,$suffix,$disk_status)=split(' ',$record);
      if ($errors eq 1) {
        $disk_status="ERROR";
      }
      else {
        if ($disk_status!~/Optimal/) {
          $disk_status=~s/Optimal/OK/g;
          add_to_bad_disk_list($disk_name,$disk_status,$file_system);
        }
        else {
          $disk_status="OK";
        }
      }
      if ($verbose eq 1) {
        print "Disk:   $disk_name\n";
        print "Status: $disk_status\n";
      }
    }
  }
  return;
}

# Process LSI mirror info

sub process_lsi_info {  
  my $counter; 
  my $record; 
  my $prefix; 
  my $number=0; 
  my $suffix; 
  my $disk_name; 
  my $file_system; 
  my $disk_status; 
  my $device_no=0;
  my $model="Logical Volume"; 
  my $manual_mount; 
  my $mirror_type;
  my $disk_group=0;
  for ($counter=0; $counter<@lsi_info; $counter++) {
    $record=$lsi_info[$counter];
    chomp($record);
    if ($record=~/Volume ID/) {
      ($prefix,$number)=split(': ',$record);
    }
    if ($record=~/Volume state|Status of volume/) {
      ($prefix,$disk_status)=split(/\:/,$record);
      if ($os_version=~/SunOS|FreeBSD/) {
        ($disk_name,$file_system)=process_fstab($number,$device_no);
      }
      else {
        $disk_name=search_device_list($model,$disk_group);  
        ($file_system,$manual_mount)=get_file_system($disk_name,$mirror_type);
      }
      $device_no++;
      if ($errors eq 1) {
        $disk_status="ERROR";
      }
      else {
        if ($disk_status!~/Optimal|Okay|ok/) {
          $disk_status=~s/Optimal/OK/g;
          add_to_bad_disk_list($disk_name,$disk_status,$file_system);
        }
        else {
          $disk_status="OK";
        }
      }
      if ($verbose eq 1) {
        $disk_status=~s/Optimal/OK/g;
        if ($os_version=~/FreeBSD/) {
          if ($disk_name=~/da$counter/) {
            print "Disk:   $disk_name\n";
            print "Status: $disk_status\n";
            print "Mount:  $file_system\n";
          }
        } 
        else {
          print "Disk:   $disk_name\n";
          print "Status: $disk_status\n";
          print "Mount:  $file_system\n";
        }
      }
    }
  }
  return;
}

# Find a dev-mapper volume name for a raid instance
# Then determine file systems and return them

sub process_fstab {
  my $number=$_[0]; 
  my $lvm_file; 
  my $file_system; 
  my $disk_name; 
  my $tester; 
  my @file_list; 
  my $prefix; 
  my $suffix; 
  my $record; 
  my $disk_name; 
  my $file_system; 
  my $delete; 
  my $raw_device; 
  my $lvm_name; 
  my $fdisk_output="/tmp/fdiskinfo";
  my $disk_id;
  $lvm_file="/tmp/$script_name.lvm";
  if ($number eq 0) {
    $number++;
  }
  $disk_id=chr($number+96);
  $disk_id="sd$disk_id";
  $tester=`cat /etc/fstab | Vol |grep -v '^#' |tail -1`;
  chomp($tester);
  if ($tester=~/Vol/) {
    system("/usr/sbin/pvs > $lvm_file");
    $lvm_name=`cat $lvm_file |grep lvm |head -$number |tail -1 |awk '{print \$2}'`;
    chomp($lvm_name);   
    system("rm $lvm_file");
    if ($lvm_name!~/lvm2/) {  
      @file_list=`cat /etc/fstab | grep -v '^#' |grep '$lvm_name' |grep dev|awk '{print \$1":"\$2}' |sort -k 1`;
    }
  }
  else {
    $tester=`cat /etc/fstab |grep sd |grep dev`;
    chomp($tester);
    if ($tester!~/sd/) {
      @file_list=`cat /etc/mtab | grep '$disk_id' |egrep 'ext|xfs' |awk '{print \$1":"\$2}' |sort -k 1`;
    }
    else {
      @file_list=`cat /etc/fstab | grep -v '^#' |grep sd |grep dev |awk '{print \$1":"\$2}' |sort -k 1`;
    }
  }
  foreach $record (@file_list) {
    chomp($record);
    ($prefix,$suffix)=split(/\:/,$record);
    if ($prefix=~/Vol/) {
      ($prefix,$delete)=split('\/LogVol',$prefix);
    }
    if ($disk_name!~/[A-z]/) {
      $disk_name="$prefix";
      $file_system="$suffix";
    }
    else {
      if ($disk_name!~/$prefix/) {
        $disk_name="$disk_name,$prefix";
      }
      if ($file_system!~/$suffix/) {
        $file_system="$file_system,$suffix";
      }
    }
  }
  system("/sbin/fdisk -l > /tmp/fdiskinfo 2>&1");
  if (-e "$fdisk_output") {
    $raw_device=`cat /tmp/fdiskinfo |grep '^Disk' |grep -v doedn |grep -v dpd|head -$number |tail -1 |cut -f1 -d ':' |cut -f2 -d ' '`;
    chomp($raw_device);
  }
  if ($tester=~/Vol/) {
    if ($lvm_name=~/lvm2/) {
      $lvm_name="Unconfigured";
    }
    $disk_name="$raw_device [$lvm_name]";
  }
  else {
    if ($tester!~/sd/) {
      $disk_name=$raw_device;
    }
  }
  return($disk_name,$file_system);
}

# code to convert sd number to cXtXdX 

sub get_controller_no {
  my $disk_no=$_[0]; 
  my $counter; 
  my $record; 
  my @disk_nos; 
  my @controller_nos; 
  my $number; 
  my $release_test; 
  my $tester=0; 
  my $instance_no; 
  my $prefix; 
  my $wwn_no; 
  my $search_string;
  my $mpxio_test=0;
  $instance_no=$disk_no;
  $instance_no=~s/[a-z]//g;
  $release_test=`uname -r`;
  chomp($release_test);
  if ($release_test=~/10/) {
    @disk_nos=`prtconf -v`;
    for ($counter=0; $counter<@disk_nos; $counter++) {
      $record=@disk_nos[$counter];
      chomp($record);
      if ($record=~/#$instance_no$/) {
        $tester=1;
      }
      if ($tester eq 1) {
        if ($record=~/dev_link/) {
          ($prefix,$disk_no)=split('=',$record);
          return($disk_no);
        }
      }
    }
  }
  else {
    if ($release_test=~/8|9/) {
      @disk_nos=`prtconf -v`;
      for ($counter=0; $counter<@disk_nos; $counter++) {
        $record=@disk_nos[$counter];
        chomp($record);
        if ($record=~/#$instance_no$/) {
          $tester=1;
        }
        if ($tester eq 1) {
          if ($record=~/mpxio/) {
            $mpxio_test=1;
          }
          if ($mpxio_test eq 1) {
            $search_string="client-guid";
          }
          else {
            $search_string="port-wwn";
          } 
          if ($record=~/$search_string/) {
            $number=$counter;
            $number++;
            $wwn_no=$disk_nos[$number];
            if (($release_test=~/8/)&&($search_string!~/guid/)) {
              ($prefix,$wwn_no)=split('0x',$wwn_no);
              $wwn_no=~s/\>//g;
            }
            else {
              ($prefix,$wwn_no)=split('=',$wwn_no);
            }
            $wwn_no=~s/\.//g;
            $wwn_no=~s/\'//g;
            chomp($wwn_no);
            if ($wwn_no=~/[0-9]/) {
              $disk_no=`ls -l /dev/dsk |grep -i '$wwn_no' |head -1| awk '{print \$9}'`;
            }
            chomp($disk_no);
            return($disk_no);
          }
        }
      }
    }
    else {
      @disk_nos=`prtconf |grep sd |grep -v attached |awk -F'#' '{print "sd"\$2}'`;
      $number=$#disk_nos+1;
      @controller_nos=`ls -l /dev/rdsk/*s0 |awk '{print \$9}' |cut -f4 -d'/' |tail -$number`;
      for ($counter=0; $counter<@disk_nos; $counter++) {
        $record=@disk_nos[$counter];
        chomp($record);
        if ($record=~/^$disk_no$/) {
          $disk_no=$controller_nos[$counter];
          chomp($disk_no);
          return($disk_no);
        }
      }
    }
  }
  return($disk_no);
}

# Get Disk ID under linux

sub get_disk_id {
  my $disk_no=$_[0]; 
  my $prefix; 
  my $suffix;
  ($prefix,$disk_no)=split("id",$disk_no);
  ($disk_no,$suffix)=split("lun",$disk_no);
  $disk_no=~s/\ //g;
  $disk_no=$disk_no+97;
  $disk_no=chr($disk_no);
  $disk_no="sd$disk_no";
  return($disk_no);
}
  
# Process system messages looking for SCSI errors

sub get_messages_info {
  my @dmesgs; 
  my $date_string; 
  my $record; 
  my $disk_status;
  my $prefix; 
  my $suffix; 
  my $bad_disk; 
  my $file_system; 
  my $mirror_type;
  my $number; 
  my $disk_no; 
  my $file_no; 
  my $list_no=0; 
  my $file_system; 
  my $mdconf_file; 
  my $marker=0; 
  my $month_string; 
  my $day_string; 
  my $hour_string; 
  my $command; 
  my @mdlist; 
  my $messages_file; 
  my $disk_status="WARNING"; 
  my $disk_group=0; 
  my $manual_mount=0;
  $date_string=`date |awk '{print \$2" "\$3" "\$4}'`;
  chomp($date_string);  
  ($month_string,$day_string,$hour_string)=split(' ',$date_string);
  ($hour_string,$suffix,$suffix)=split("\:",$hour_string);
  if ($day_string=~/[0-9][0-9]/) {
    $day_string="$month_string $day_string";
    $date_string="$day_string $hour_string";
  }
  else {  
    $day_string="$month_string  $day_string";
    $date_string="$day_string $hour_string";
  }
  if ($os_version=~/SunOS/) {
    if ($option{'n'}) {
      return;
    }
    $messages_file="/var/adm/messages";
    if ($option{'A'}) {
      $command="cat $messages_file |grep WARN |grep scsi |grep -v fibre |grep -v JNI |uniq |awk '{print \$11}' |grep sd |sort |uniq";
    }
    else {
      if ($option{'F'}) {
        $command="cat $messages_file |grep WARN |grep scsi |grep -v fibre |grep -v JNI |uniq |grep '^$day_string' |awk '{print \$11}' |grep sd |sort |uniq";
      }
      else {
        $command="cat $messages_file |grep WARN |grep scsi |grep -v fibre |grep -v JNI |uniq |grep '^$date_string' |awk '{print \$11}' |grep sd |sort |uniq";
      }
    }
    @dmesgs=`$command`;
  }
  else {
    if ($os_version=~/Linux|linux/) {
      $messages_file="/var/log/messages";
      if ($option{'A'}) {
        $command="cat $messages_file |egrep 'SCSI|I/O' |grep -i 'error' |cut -f5 -d':' |sort |uniq";
      }
      else {
        if ($option{'F'}) {
          $command="cat $messages_file |egrep 'SCSI|I/O' |grep -i 'error' |grep '^$day_string' |cut -f5 -d':' |sort |uniq";
        }
        else {
          $command="cat $messages_file |egrep 'SCSI|I/O' |grep -i 'error' |grep '^$date_string' |cut -f5 -d':' |sort |uniq";
        }
      }
      @dmesgs=`$command`;
    }
  }
  foreach $bad_disk (@dmesgs) {
    chomp($bad_disk);
    if ($os_version=~/Linux|linux/) {
      if ($bad_disk=~/I\/O [E,e]rror/) {
        ($prefix,$bad_disk,$suffix)=split(",",$bad_disk);
        $bad_disk=~s/dev//g;
        $bad_disk=~s/ //g;
        $disk_no=$bad_disk;
      }
      else {
        $disk_no=get_disk_id($bad_disk);
      }
      $disk_status="WARNING";
      ($file_system,$manual_mount)=get_file_system($disk_no,$mirror_type);
      add_to_bad_disk_list($disk_no,$disk_status,$file_system);
    }
    if ($os_version=~/SunOS/) {
      $bad_disk=~s/\(//g;
      $bad_disk=~s/\)//g;
      $bad_disk=~s/\://g;
      $bad_disk=get_controller_no($bad_disk);
      $bad_disk=~s/ //g;
      $bad_disk=~s/s0//g;
      if ($sds_test eq 1) {
        $mirror_type="md";
        if (-e "/etc/lvm/md.cf") {
          $mdconf_file="/etc/lvm/md.cf";
        }
        else {
          $mdconf_file="/etc/opt/SUNWmd/md.cf";
        }
        @mdlist=`cat $mdconf_file |grep '^d' | grep '$bad_disk' |awk '{print \$1}'`;
        if ($mdlist[0]!~/c/) {
            $mirror_type="fs";
            if ($bad_disk=~/c/) {
              ($file_system,$manual_mount)=get_file_system($bad_disk,$mirror_type);
              add_to_bad_disk_list($disk_no,$disk_status,$file_system);
            }
        }
        else {
          for ($number=0; $number<@mdlist; $number++) {
            $disk_no=$mdlist[$number];
            chomp($disk_no);
            $disk_no=`cat $mdconf_file |grep '$disk_no' |grep -v '^$disk_no' |grep -v '^#' |awk '{print \$1}'`;
            chomp($disk_no);
            ($file_system,$manual_mount)=get_file_system($disk_no,$mirror_type);
            add_to_bad_disk_list($disk_no,$disk_status,$file_system);
          }
        }
      }
      if ($veritas_test eq 1) {
        $disk_no=$bad_disk;
        $mirror_type="vx";
        @mdlist=`vxdisk list |grep '$bad_disk' |awk '{print \$4}'`;
        for ($number=0; $number<@mdlist; $number++) {
          $disk_group=$mdlist[$number];
          chomp($disk_group);
          ($file_system,$manual_mount)=get_file_system($disk_group,$mirror_type);
          add_to_bad_disk_list($disk_no,$disk_status,$file_system);
        }   
      }
      if (($sds_test ne 1)&&($veritas_test ne 1)) {
        $mirror_type="fs";
        ($file_system,$manual_mount)=get_file_system($bad_disk,$mirror_type);
        add_to_bad_disk_list($bad_disk,$disk_status,$file_system);
      }
      else {
        if ($manual_mount eq 1) {
          $mirror_type="fs";
          ($file_system,$manual_mount)=get_file_system($bad_disk,$mirror_type);
          add_to_bad_disk_list($bad_disk,$disk_status,$file_system);
        }
      }
    }
  } 
  return;
}

# Get Dynapath Disk ID

sub get_dynapath_device {
  my $disk_no=$_[0]; 
  my $prefix; 
  my $suffix;
  my $record; 
  my $counter; 
  my $number; 
  my $tester;
  if ($dynapath_info[0]!~/=/) {
    @dynapath_info=`$dynapath_command status`;
  }
  for ($counter=0; $counter<@dynapath_info; $counter++) {
    $record=$dynapath_info[$counter];
    chomp($record);
    if ($record=~/$disk_no/) {
      $number=$counter;
      $number++;
      $tester=$dynapath_info[$number];
      chomp($number);
      if ($tester!~/dp/) {
        $number++;
        $tester=$dynapath_info[$number];
        chomp($number);
      }
      if ($tester=~/dp/) {
        ($disk_no,$suffix)=split('\(',$tester);
        ($prefix,$disk_no)=split('=',$disk_no);
        return($disk_no);
      }
    }
  }
  return($disk_no);
}

# Get Filesystem lists

sub get_file_system {
  my $disk_no=$_[0]; 
  my $mirror_type=$_[0]; 
  my $file_system; 
  my $file_name; 
  my @file_info; 
  my $manual_mount=0; 
  my $pvscan; 
  my $id_no;
  if ($os_version=~/SunOS/) {
    if ($mirror_type=~/fs/) {
      @file_info=`grep -i '$disk_no' /etc/vfstab |grep -v '^#' |awk '{print \$3}'`;
    }
    else {
      @file_info=`grep -i '$disk_no' /etc/vfstab |grep -v '^#' |grep '$mirror_type' |awk '{print \$3}'`;
    }
  }
  else {
    if (-e "/usr/local/dynapath") {
      $disk_no=get_dynapath_device($disk_no);
    } 
    @file_info=`grep -i '$disk_no' /etc/fstab |grep -v '^#' |awk '{print \$2}'`;
    if ($file_info[0]!~/[A-z]|[0-9]|\//) {
      $pvscan=`pvscan |grep '$disk_no' |awk '{print \$4}'`;
      chomp($pvscan);
      if ($pvscan=~/^Vol/) {
        @file_info=`egrep -i '$disk_no|$pvscan' /etc/fstab |grep -v '^#' |awk '{print \$2}'`;
      }
    }
    if ($file_info[0]!~/[A-z]|[0-9]|\//) {
      if (-e "/dev/disk/by-id") {
        $id_no=`ls -l /dev/disk/by-id/scsi* |grep '$disk_no' |awk '{print \$9}' |head -1`;
        chomp($id_no);
        @file_info=`grep -i '$id_no' /etc/fstab |grep -v '^#' |awk '{print \$2}'`;
        
      }
    }
  }
  if ($file_info[0]!~/[A-z]|[0-9]|\//) {
    @file_info=`df |grep -i '$disk_no' |awk '{print \$6}'`;
  } 
  if ($file_info[0]=~/[A-z]|[0-9]|\//) {
    $manual_mount=1;
  }
  foreach $file_name (@file_info) {
    chomp($file_name);
    $file_name=~s/ //g;
    if ($file_name!~/\//) {
      $file_name="swap";
    }
    if ($file_name=~/[0-9]|[A-z]|\//) {
      if ($file_system!~/$file_name/) { 
        if ($file_system=~/[0-9]|[A-z]|\//) {
          $file_system="$file_system, $file_name";
        }
        else {
          $file_system=$file_name;
        }
      }
    }
  }   
  if ($file_info[0]!~/[A-z]|[0-9]|\//) {
    $file_system="None";
  }
  return($file_system,$manual_mount);
}

# Process disk information looking for errors and act according to options

sub process_disk_info {
  my $disk_name; 
  my $disk_status; 
  my $file_system; 
  my $record; 
  my $hostname=`hostname`; 
  my $tester; 
  my $string_test=0;
  chomp($hostname);
  if (($bad_disk_list[0]=~/[A-z]|[0-9]/)||($bad_disk_list[1]=~/[A-z]|[0-9]/)) {
    $string_test=1;
  }
  if (($string_test eq 1)&&($verbose ne 1)) {
    if ($option{'P'}) {
      print "2\n";
      exit;
    }
    if (($option{'m'})||($option{'s'})||($option{'h'})) {
      $output="$temp_dir/mdoutput";
      if (-e "$output") {
        system("rm $output");
        system("touch $output");
      }
      open(STDOUT,">$output");
      print STDOUT "Disk Errors:\n";
      print STDOUT "\n";
      foreach $record (@bad_disk_list) {
        ($disk_name,$disk_status,$file_system)=split(/\|/,$record);
        if ($disk_name=~/^[A-z]/) {
          $disk_status=~s/Optimal/OK/g;
          print STDOUT "Disk:     $disk_name\n";
          print STDOUT "Status:   $disk_status\n";
          print STDOUT "Mount:    $file_system\n";
          print STDOUT "\n";
        }
      }
      close STDOUT;
      if ($option{'m'}) {
        if ($option{'n'}) {
          system("cat $output");
        }
        else {
          if ((-e "$date_file")&&(!$option{'t'})) {
            $tester=`diff $output $date_file`;
            if ($tester=~/[A-z]/) {
              system("rm $date_file");
            }
          }
          if ((!-e "$date_file")||($option{'t'})) {
            $tester=`cat $output |grep -v '^Disk Errors'`;  
            if ($tester=~/[A-z]/) {
              if ($os_version=~/[L,l]inux/) {
                system("cat $output |mail -s\"$script_name: $hostname\" $email_address");
              }
              else {
                system("cat $output |mailx -s\"$script_name: $hostname\" $email_address");
              }
              system("cp $output $date_file");  
            }
          }
        }
      }
      else {
        if ($option{'s'}) {
          system("/usr/bin/logger -f $output -p local4.notice");
        }
      }
      if (-e "$output") {
        system("rm $output");
      }
    }
    else {
      print "Disk Errors:\n\n";
      foreach $record (@bad_disk_list) {
        $disk_status=~s/Optimal/OK/g;
        ($disk_name,$disk_status,$file_system)=split(/\|/,$record);
        print "Disk:  $disk_name\n";
        print "Status:  $disk_status\n";
        print "Mount: $file_system\n";
      }
      print "\n"; 
    } 
  }
  else {
    if ($option{'P'}) {
      print "3\n";
      exit;
    }
  }
  return;
}

