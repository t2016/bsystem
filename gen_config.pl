#!/usr/bin/perl
use 5.010;
use strict;
use warnings;

chomp @ARGV;

my $mock_filename = shift(@ARGV);
chomp $mock_filename;

my %config_opts;
$config_opts{'root'} = shift(@ARGV); 
$config_opts{'target_arch'} = shift(@ARGV);
$config_opts{'legal_host_arches'} = shift(@ARGV);
$config_opts{'chroot_setup_cmd'} = 'install @'.shift(@ARGV);
$config_opts{'dist'} = shift(@ARGV);
$config_opts{'releasever'} = shift(@ARGV); 		
$config_opts{'yum.conf'} = '"""';

$config_opts{'repos'} = '';	
while (@ARGV) {
	my $url_repo = shift(@ARGV);
	my @arr_url = split '\*', $url_repo;
	my $repo = <<"END_REPO";
[$arr_url[0]]
name=$arr_url[0]
baseurl=$arr_url[-1]
enabled=1
gpgcheck=0
END_REPO
	$config_opts{'repos'} .=$repo."\n";
}

my $conf = <<"END_CONF";
config_opts['root'] = '$config_opts{'root'}'
config_opts['target_arch'] = '$config_opts{'target_arch'}'
config_opts['legal_host_arches'] = ('$config_opts{'legal_host_arches'}',)
config_opts['chroot_setup_cmd'] = '$config_opts{'chroot_setup_cmd'}'
config_opts['dist'] = '$config_opts{'dist'}'
config_opts['releasever'] = '$config_opts{'releasever'}'

config_opts['yum.conf'] = $config_opts{'yum.conf'}
[main]
cachedir=/var/cache/yum
keepcache=1
debuglevel=2
reposdir=/dev/null
logfile=/var/log/yum.log
retries=20
obsoletes=1
gpgcheck=0
assumeyes=1
syslog_ident=mock
syslog_device=

# repos
END_CONF

$conf .= "\n".$config_opts{'repos'}.$config_opts{'yum.conf'};

open FILE, ">", "/etc/mock/$mock_filename" or die "Could not open file '/etc/mock/$mock_filename' $!";
say FILE $conf;
close FILE;
