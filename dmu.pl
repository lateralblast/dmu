#!/usr/bin/env perl

# Name:         dmu (Disk Monitoring Utility)
# Version:      1.4.8
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

# Initialise global variables

my $version_no="1.4.7";
my $script_name="dmu"; 
my %option; 
my $verbose=0; 
my $temp_dir="/var/$script_name"; 
my $file_system; 
my $zone_name; 
my $date_file; 
my @change_log; 
my $coder_email="richard\@lateralblast.com.au";
my $output="$temp_dir/$script_name.log"; 
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
my $update_server="updateserver.vendor.com"; 
my $command_line; 
my $date_no; 
my $version_file;
my $dynapath_test=0; 
my @dynapath_info;
my $dynapath_command="/usr/local/dynapath/bin/dpcli";
my $monitor_user="nimsoft";
my $monitor_uid="";
my $monitor_gid="";
my $monitor_gcos="";
my $file_slurp=0;
my $pod_exe;

# By default set network update to off

$option{'n'}=1;

chomp($os_version);

# Add handling for being run as mdcheck

if ($script_file=~/mdcheck/) {
  $temp_dir="/var/log/mdcheck";
}

$version_file="$temp_dir/$script_name.version"; 

# Get command line options

getopts("cfhlk:mnstvAFPVd:",\%option);

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
# Install File::Slurp 
##################################################################

sub install_file_slurp { 
  my $perl_module="File::Slurp";
  my $package_name="perl-File-Slurp";
  my $package_version="9999.13-1";
  install_perl_module($package_name,$package_version,$perl_module);
  return;
}

##################################################################
# Install a perl module 
##################################################################

sub install_perl_module {
  my $package_name=$_[0]; 
  my $package_version=$_[1];
  my $release_test; 
  my $release_file="/etc/redhat-release";
  my $remote_base="/pub/linux/extra/dag/redhat/";
  my $local_file; 
  my $remote_file; 
  my $release_string;
  my $perl_test; 
  my $perl_module=$_[2]; 
  my $tester=0;
  $perl_test=`rpm -qi $package_name |grep Version`;
  chomp($perl_test);
  if ($perl_test=~/[0-9]/) {
    print "$perl_module not installed correctly.\n";
    return;
  }
  else {
    $tester=1;
  }
  if ($tester eq 1) {
    if (-e "$release_file") {
      $release_test=`cat $release_file`;
      chomp($release_test);
      if ($release_test=~/release 3/) {
        $release_string="el3";
        $remote_base="$remote_base/$release_string/en/i386/dag/RPMS"; 
        $remote_file="$package_name-$package_version.$release_string.rf.noarch.rpm";
        $local_file="/tmp/$remote_file";
        $remote_file="$remote_base/$remote_file";
      }
      else {
        if ($release_test=~/release 4/) {
          $release_string="el4";
          $remote_base="$remote_base/$release_string/en/i386/dag/RPMS";
          $remote_file="$package_name-$package_version.$release_string.rf.noarch.rpm";
          $local_file="/tmp/$remote_file";
          $remote_file="$remote_base/$remote_file";
        }
        else {  
          if ($release_test=~/release 5/) {
            if ($package_name=~/Telnet/) {
              $package_version="3.03-1.2";
            }
            $release_string="el5";
            $remote_base="$remote_base/$release_string/en/i386/dag/RPMS";
            $remote_file="$package_name-$package_version.$release_string.rf.noarch.rpm";
            $local_file="/tmp/$remote_file";
            $remote_file="$remote_base/$remote_file";
          }
        }
      }
    }
    get_ftp_file($remote_file,$local_file);
    if (-e "$local_file") {
      print "Installing $perl_module\n";
      system("cd /tmp ; rpm -ivh $local_file");
      system("rm -f $local_file");
    }
    $release_file="/etc/SuSE-release";
    if ($tester eq 1) {
      if (-e "$release_file") {
        $remote_base="/pub/sun/$script_name/tools/"; 
        $remote_file="perl-File-Slurp-9999.13-9.pm.15.1.noarch.rpm";
        $local_file="/tmp/$remote_file";
        $remote_file="$remote_base/$remote_file";
        get_ftp_file($remote_file,$local_file);
        if (-e "$local_file") {
          print "Installing $perl_module\n";
          system("cd /tmp ; rpm -ivh $local_file");
          system("rm -f $local_file");
        }
      }
    }
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
  if (!$option{'n'}) {
    if ($file_slurp eq 0) {
      install_file_slurp();
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

# populate changelog

if ($option{'k'}=~/[0-9][0-9]/) {
  populate_change_log();
  print_version_change($option{'k'});
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

# Code to upgrade script if a newer version is available 

sub upgrade_script_file {      
  my $remote_file="/pub/sun/$script_name/$script_name"; 
  my $local_file=$script_file;      
  get_ftp_file($remote_file,$local_file);
  if (!$option{'n'}) {
    check_script_file();
  }
  return;
}

# Check version of script against remote version

sub check_version_stub {
  my $remote_stub; 
  my $local_stub; 
  my $remote_version;
  my $remote_file="/pub/sun/$script_name/version";
  if (!-e "$temp_dir") {
    system("mkdir -p $temp_dir");
  }
  get_ftp_file($remote_file,$version_file);
  if (-e "$version_file") {
    $remote_version=`cat $version_file`; chomp($remote_version);
    $remote_stub=$remote_version; $local_stub=$version_no;
    $remote_stub=~s/\.//g; $remote_stub=~s/^0//g; $remote_stub=~s/\ //g;
    $local_stub=~s/\.//g; $local_stub=~s/^0//g; $local_stub=~s/\ //g;
    if ($remote_stub > $local_stub) {
      print "Local version of $script_name: $version_no\n";
      print "Patch version of $script_name: $remote_version\n";
      print "Upgrading $script_name to $remote_version... ";
      upgrade_script_file();
      print "Done.\n";
      if ($option{'V'}) {
        print "Executing: $script_file -k $version_no $command_line\n";
      }
      system("$script_file -k $version_no $command_line");
      exit;
    }
  }
  return;
}

# Code to fetch a file via ftp
# remote_file must contain full path of file eg /pub/blah/file.tgz
# local_file must contain pull path of file eg /tmp/file.tgz

sub get_ftp_file {
  my $remote_file=$_[0]; 
  my $local_file=$_[1]; 
  my $ftp_session;
  my $userid="anonymous"; 
  my $password="guest@";
  $ftp_session=Net::FTP->new("$update_server", Passive=>1, Debug=>0);
  $ftp_session->login("$userid","$password");
  $ftp_session->type("I");
  $ftp_session->get("$remote_file","$local_file");
  $ftp_session->quit;
  return;
}

# Check permissions on exe file so monitor_user can run it etc

sub check_script_file {
  my $monitor_user_test=`cat /etc/group |grep $monitor_user`;
  chomp($monitor_user_test);
  if ($monitor_user_test=~/$monitor_user/) {
    system("chown root:$monitor_user $script_file");
    system("chmod 750 $script_file");
  }
  return;
} 

# Search Linux device list

sub search_device_list {
  my $search_string=$_[0]; 
  my $disk_group=$_[1]; 
  my $suffix;
  my $counter; 
  my $record; 
  my $disk_name="unknown"; 
  my $number=0;
  for ($counter=0; $counter<@device_list; $counter++) {
    $record=$device_list[$counter];
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
  my $counter; 
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
  my $ips_string="/proc/scsi/ips"; 
  my $tester; 
  my $counter;
  my $adaptec_proc="/proc/scsi/aacraid"; 
  my $adaptec_command; 
  my $adaptec_remote; 
  my $adaptec_no; 
  my $serveraid_no; 
  my $firmware_test; 
  my $firmware_command; 
  my $suffix;
  my $ibmraid_remote; 
  my $release_test; 
  my $prefix;
  my $remote_file; 
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
  $tester=`id`;
  chomp($tester);
  check_file_slurp();
  # If run by monitor_user don't update script
  if ($tester=~/$monitor_user/) {
    $option{'n'}=1;
  }
  else {
    # Code to create manual
    if (!$option{'n'}) {
      if ($os_version=~/[L,l]inux/) {
        if (!-e "$man_dir") {
          system("mkdir $man_dir");
        } 
        $man_file="/usr/local/share/man/man1/$script_name.man";
        if ((!-e "$man_dir")&&($tester!~/$monitor_user/)) {
          system("mkdir -p $man_dir");
        }
        $pod_exe="/usr/bin/pod2man";
        $tester=`cat /etc/group |grep '^disk'`;
        chomp($tester);
        if ($tester!~/$monitor_user/) {
          $tester=`cat /etc/group |grep '^$monitor_user'`;
          chomp($tester);
          if ($tester!~/$monitor_user/) {
            system("/usr/sbin/groupadd -g $monitor_gid $monitor_user");
          }
          $tester=`cat /etc/passwd |grep '^$monitor_user'`;
          chomp($tester);
          if ($tester!~/$monitor_user/) {
            system("/usr/sbin/useradd -u $monitor_uid -g $monitor_gid -c '$monitor_gcos' -d /home/$monitor_user $monitor_user -m");
            #system("/usr/bin/passwd -l $monitor_user");
          }
          system("/usr/sbin/usermod -G disk $monitor_user");
        }
      }
      if ($os_version=~/Sun/) {
        $man_file="/usr/man/man1/$script_name.man";
        $pod_exe="/usr/local/bin/pod2man";
        if (! -e "$pod_exe") {
          $pod_exe="/usr/local/perl/bin/pod2man";
        }
      }
    }
    check_script_file();
    if (! -e "$man_file") {
      if (-e "$pod_exe") {
        system("$pod_exe $script_file > $man_file");
      }
    }
    if ($option{'n'}) {
      $temp_dir="/tmp/$script_name";
    }
    if (!-e "$temp_dir") {
      system("mkdir -p $temp_dir");
    }
  }
  # Check config of Linux
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
        $adaptec_remote="/pub/sun/$script_name/tools/arcconfel5";
      }
      else {
        $adaptec_command="/usr/local/bin/arcconf";
        $adaptec_remote="/pub/sun/$script_name/tools/arcconf";
      }
      if (! -e "$adaptec_command") {
        get_ftp_file($adaptec_remote,$adaptec_command);
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
            $ibmraid_remote="/pub/sun/$script_name/tools/ipssend$ibmraid_test";
            get_ftp_file($ibmraid_remote,$ibmraid_command);
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
          $remote_file="/pub/sun/$script_name/tools/cfg1064";
          $command="$lsi_command 0 DISPLAY";
        }
        else {
          $lsi_command="/usr/local/bin/cfg1030";
          $remote_file="/pub/sun/$script_name/tools/cfg1030";
          $command="$lsi_command getstatus 1";
        }
        if (! -e "$lsi_command") {
          get_ftp_file($remote_file,$lsi_command);
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
        chomp($lsi_test);;
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
  print_help_info();
  exit;
}

# version information

if ($option{'v'}) {
  print_version_info();
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

# Print change in version information

sub print_version_change {
  my $number=$_[0]; my $counter; my $record;
  print "\n";                                                     
  if ($number!~/[0-9]/) {                                         
    print "Fixes since last update:\n";                     
  }                                                               
  else {                                                          
    print "Fixes since $number:\n";                         
  }                                                               
  print "\n";                                                     
  $number=~s/\.//g;
  for ($counter=$number; $counter<@change_log; $counter++) {
    $record=$change_log[$counter];
    chomp($record);
    print "$record\n";
  }
  return;
}                    

# Print help information

sub print_help_info {
  $pod_exe=`which pod2text`;
  chomp($pod_exe);
  if ($pod_exe=~/^no/) {
    $pod_exe=`find /usr/perl5 -name pod2text |head -1`;
    chomp($pod_exe);
  }
  system("$pod_exe $0");  
  return;
}

# Print version information

sub print_version_info {
  print "\n";
  print "$script_name v $version_no $coder_email\n";
  print "\n";
  return;
}

# Print changelog

sub print_change_log {

  my $counter; my $record; my $temp_version; my $temp_name; my $tmpdat; my $tmpstr;

  if ($change_log[0]!~/[A-z]/) {
    populate_change_log();
  }
  print_version_info();
  for ($counter=0; $counter<@change_log; $counter++) {
    $record=$change_log[$counter];
    chomp($record);
    print "$record\n";
  }
  print "\n";
  return;
}

# Populate change log

sub populate_change_log {

  my $remote_file="/pub/sun/$script_name/changelog"; my $counter;
  my $local_file="/tmp/changelog"; my $record;

  if (-e "$local_file") {
    system("rm $local_file");
  }
  get_ftp_file($remote_file,$local_file);
  if (-e "$local_file") {
    @change_log=`cat $local_file`;
  }
  return;

}

# Add to bad disk list

sub add_to_bad_disk_list {
  my $disk_name=$_[0]; 
  my $disk_status=$_[1]; 
  my $file_system=$_[2];
  my $counter; 
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
  for ($counter=0; $counter<@bad_disk_list; $counter++) {
    $record=$bad_disk_list[$counter];
    if ($record=~/^$disk_name/) {
      $tester=1;
    }
    if ($record=~/$file_system/) {
      $tester=1;
    }
  }
  if ($tester eq 0) {
    $bad_disk_list[$marker]="$disk_name|$disk_status|$file_system";
    $marker++;
  }
  return;
}

# Process LSI SASx36 Information

sub process_sasx36_info {

  my $sasx36_command="/opt/MegaRAID/MegaCli/MegaCli64";
  my $sasx36_rpm_1="MegaCli-8.00.16-1.i386.rpm";
  my $sasx36_rpm_2="Lib_Utils-1.00-07.noarch.rpm";
  my $sasx36_rpm_3="Lib_Utils2-1.00-01.noarch.rpm";
  my $sasx36_rpm_4="MSM_linux_installer-8.00-05.tar.gz";
  my $sasx36_rpm_5="libstdc++33-32bit-3.3.3-11.9.x86_64.rpm";
  my $sasx36_rpm_6="libgcc43-32bit-4.3.3_20081022-11.18.x86_64.rpm";
  my $sasx36_rpm_7="libstdc++43-32bit-4.3.3_20081022-11.18.x86_64.rpm";
  my $remote_file_1="/pub/sun/$script_name/tools/$sasx36_rpm_1";
  my $remote_file_2="/pub/sun/$script_name/tools/$sasx36_rpm_2";
  my $remote_file_3="/pub/sun/$script_name/tools/$sasx36_rpm_3";
  my $remote_file_4="/pub/sun/$script_name/tools/$sasx36_rpm_4";
  my $remote_file_5="/pub/linux/sles/11.0/suse/x86_64/$sasx36_rpm_5";
  my $remote_file_6="/pub/linux/sles/11.0/suse/x86_64/$sasx36_rpm_6";
  my $remote_file_7="/pub/linux/sles/11.0/suse/x86_64/$sasx36_rpm_7";
  my $local_file_1="/tmp/$sasx36_rpm_1"; 
  my $local_file_2="/tmp/$sasx36_rpm_2"; 
  my $local_file_3="/tmp/$sasx36_rpm_3"; 
  my $local_file_4="/tmp/$sasx36_rpm_4"; 
  my $local_file_5="/tmp/$sasx36_rpm_5"; 
  my $local_file_6="/tmp/$sasx36_rpm_6"; 
  my $local_file_7="/tmp/$sasx36_rpm_7"; 
  my $sasx36_init="/etc/init.d/mrmonitor";
  my $counter; 
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
    get_ftp_file($remote_file_6,$local_file_6);
    if (-e "$local_file_6") {
      system("rpm -i $local_file_6");
      system("rm -f $local_file_6");
    }
    get_ftp_file($remote_file_5,$local_file_5);
    if (-e "$local_file_5") {
      system("rpm -i $local_file_5");
      system("rm -f $local_file_5");
    }
  }
  if (! -e "/usr/lib/libstdc++.so.6") {
    get_ftp_file($remote_file_7,$local_file_7);
    if (-e "$local_file_7") {
      system("rpm -i $local_file_7");
      system("rm -f $local_file_7");
    }
  } 
  if (! -e "$sasx36_command") {
    get_ftp_file($remote_file_2,$local_file_2);
    if (-e "$local_file_2") {
      system("rpm -i $local_file_2");
      system("rm -f $local_file_2");
    }
    get_ftp_file($remote_file_3,$local_file_3);
    if (-e "$local_file_3") {
      system("rpm -i $local_file_3");
      system("rm -f $local_file_3");
    }
    get_ftp_file($remote_file_1,$local_file_1);
    if (-e "$local_file_1") {
      system("rpm -i $local_file_1");
      system("rm -f $local_file_1");
    }
  }
  if (! -e "$sasx36_init") {
    get_ftp_file($remote_file_4,$local_file_4);
    if (-e "$local_file_4") {
      system("tar -xpf $local_file_4");
      system("cd /tmp/disk ; ./RunRPM.sh");
      system("cd /tmp");
      system("rm -rf /tmp/disk");
    }
  }
  @sasx36_info=`$sasx36_command -CfgDsply -aAll`;
  for ($counter=0; $counter<@sasx36_info; $counter++) {
    $record=@sasx36_info[$counter];
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
  my $remote_file="/pub/sun/$script_name/tools/$h700_rpm";
  my $local_file="/tmp/$h700_rpm"; 
  my $counter; 
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
    get_ftp_file($remote_file,$local_file);
    if (-e "$local_file") {
      system("rpm -i $local_file");
      system("rm -f $local_file");
    }
  }
  @h700_info=`$h700_command -CfgDsply -aAll`;
  for ($counter=0; $counter<@h700_info; $counter++) {
    $record=@h700_info[$counter];
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
  my $counter; 
  my $record; 
  my $suffix; 
  my $prefix;
  my $disk_name; 
  my $disk_status; 
  my $file_system;
  my $manual_mount; 
  my $mirror_type; 
  my $disk_temp;
  for ($counter=0; $counter<@dynapath_info; $counter++) {
    $record=$dynapath_info[$counter];
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
  my $counter; 
  my $record; 
  my $disk_name; 
  my $suffix;
  my $file_system; 
  my $group_name; 
  my $disk_status;
  for ($counter=0; $counter<@veritas_info; $counter++) {
    $record=$veritas_info[$counter];
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
  my $counter; 
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
  for ($counter=0; $counter<@zfs_info; $counter++) {
    $record=$zfs_info[$counter];
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
  my $counter; 
  my $record;
  my @zpool_list=`zpool list |grep -v '^NAME' |awk '{print \$1}'`;
  my $zpool_name="";
  $disk_name=~s/\/dev\/dsk\///g;
  for ($counter=0; $counter<@zpool_list; $counter++) {
    $record=$zpool_list[$counter];
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
  my $counter; 
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
  for ($counter=0; $counter<@raidctl_info; $counter++) {
    $record=$raidctl_info[$counter];
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
  my $counter;
  my $record;
  my $disk_status; 
  my $tester=0; 
  my $prefix; 
  my $disk_name;
  my $suffix; 
  my $vendor; 
  my $models; 
  my $errors;
  for ($counter=0; $counter<@dac960_info; $counter++) {
    $record=$dac960_info[$counter];
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

sub process_i2o_info {
  my $file_system="NA"; 
  my $counter; 
  my $record;
  my $disk_target_id; 
  my $disk_channel; 
  my $disk_target; 
  my $disk_lun; 
  my $disk_name; 
  my $disk_status;
  for ($counter=0; $counter<@i2o_info; $counter++) {
    $record=$i2o_info[$counter];
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
  my $counter; 
  my $record; 
  my $prefix;
  my $suffix; 
  my $disk_name; 
  my $file_system; 
  my $device_name;
  my $tester=0; 
  my $disk_status; 
  my $number;
  for ($counter=0; $counter<@ibmraid_info; $counter++) {
    $record=$ibmraid_info[$counter];
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
  my $counter; 
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
  for ($counter=0; $counter<@adaptec_info; $counter++) {
    $record=$adaptec_info[$counter];
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
  my $counter; 
  my $record;
  my $disk_name; 
  my $suffix; 
  my $disk_status; 
  my $file_system;
  for ($counter=0; $counter<@freebsd_info; $counter++) {
    $record=$freebsd_info[$counter];
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

#
# Find a dev-mapper volume name for a raid instance
# Then determine file systems and return them
#

sub process_fstab {
  my $number=$_[0]; 
  my $lvm_file; 
  my $file_system; 
  my $disk_name; 
  my $tester; 
  my $counter; 
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
  for ($counter=0; $counter<@file_list; $counter++) {
    $record=$file_list[$counter];
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

#
# code to convert sd number to cXtXdX 
#

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
  my $counter; 
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
  for ($counter=0; $counter<@dmesgs; $counter++) {
    $bad_disk=$dmesgs[$counter];
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
  my $file_counter;
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
  for ($file_counter=0; $file_counter<@file_info; $file_counter++) {
    $file_name=$file_info[$file_counter];
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
  my $counter; 
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
      for ($counter=0; $counter<@bad_disk_list; $counter++) {
        $record=$bad_disk_list[$counter];
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
      for ($counter=0; $counter<@bad_disk_list; $counter++) {
        $disk_status=~s/Optimal/OK/g;
        $record=$bad_disk_list[$counter];
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

__END__

=head1 NAME

dmu - Disk Monitoring Utility

=head1 SYNOPSIS

dmu [OPTIONS]

=head1 DESCRIPTION

dmu is a tool for checking software and hardware mirroring on 
a number of Unix platforms.

B<Some features of dmu>

Is capable of self updating

Supports multiple mirroring types and controllers in the same machine.

Supports reporting via email and syslog.

=head1 OPTIONS

B<-h> Display help

B<-v> Display version information

B<-c> Display change log

B<-l> Display list of mirrored disks 

B<-f> Display warning messages if any (during this hour)

B<-F> Display warning messages if any (during this day)

B<-A> Display warning messages if any

B<-m> If an error is found send email

B<-s> If an error is found create syslog message

B<-t> Induce false errors (for testing purposes)

B<-n> Run in non network mode (no check for updates)

B<-P> Print error codes for Patrol

B<-V> Verbose output

B<-H> Disable heat logging if error found

=head1 EXAMPLES

Show disk information including status:

B<dmu -l>

Mail errors if they are found (including logging to heat)

B<dmu -m>

Display warning messages created during this hour

B<dmu -f>

Mail errors if they are found (excluding logging to heat)

B<dmu -m -H>

Introduce false errors and send email

B<dmu -m -t>

=head1 AUTHOR

richard@lateralblast.com.au
