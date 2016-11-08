#!/usr/bin/perl
use 5.010;
use strict;
use warnings;
use Cwd;
use Config::YAML;

sub parse_config_r {
	my $config = Config::YAML->new( config => 'config.yaml' );
	my @elems = @{ $config->{'repository'} };

	my @repos;
	for my $i (0..$#elems ) {
		my %repo = %{ $config->{'repository'}->[$i]} ;
		foreach my $key(keys %repo) {
			my $r = $key.'*'.$config->{'repository'}->[$i]->{$key};
			push @repos, $r;
		}
	}
	return \@repos;
}

my @repos = @{ parse_config_r() };

main();


##
## cgen()
##
## Аргументы:
##    $root: $string  Имена rootdir для mock
##    $repos: @string Массив репозиториев
##	  $progname: $string Скрипт для генерации конфига mock
##
## Возврат: имя конфига mock
#  печатать созданного для mock конфига 
##
sub cgen {
	# Функция для создания конфига mock

	my $root = shift;
	my $repos = shift;
	my $progname = shift;
	my @repos = @$repos;

	my %config_opts;
	$config_opts{'mock_filename'} = $root.'.cfg';	
	$config_opts{'root'} = $root;
	$config_opts{'target_arch'} = 'x86_64'; 
	$config_opts{'legal_host_arches'} = 'x86_64';
	$config_opts{'chroot_setup_cmd'} = 'buildsys-build';
	$config_opts{'dist'} = 'el7';
	$config_opts{'releasever'} = '7';

	my $run = 'perl'.' ';
	$run .= $progname.' ';
	$run .= $config_opts{'mock_filename'}.' ';
	$run .= $config_opts{'root'}.' ';
	$run .= $config_opts{'target_arch'}.' ';
	$run .= $config_opts{'legal_host_arches'}.' ';
	$run .= $config_opts{'chroot_setup_cmd'}.' ';
	$run .= $config_opts{'dist'}.' ';
	$run .= $config_opts{'releasever'}.' ';
	foreach my $repo (@repos) {
		$run .=$repo.' ';
	}
	chop $run;
	#say "[cgen] /etc/mock/$config_opts{'mock_filename'}";
	`$run`;
	if (-e "/etc/mock/$config_opts{'mock_filename'}") {
		return $config_opts{'mock_filename'};
	} 
	return undef;
}

##
## pget()
##
sub pget {
	my $path = shift;
	my $temp = shift;
	my $dir = getcwd();
	chdir $temp;
	if (defined $path) {
		if ($path=~/\//) {
			my @words = split '/', $path;
			if (-f "./$words[-1]") {
				unlink "./$words[-1]";
			}

			system("wget $path &>/dev/null");
			if ( -f  "$temp/$words[-1]" ) {
				system("chmod 755 ./$words[-1]");
			}
			chdir $dir;
			if (-f "$temp/$words[-1]") {
				return $words[-1];
			}
		}
	}
	return undef;
}

##
## pbuild()
##
sub pbuild {
	my $pname = shift;
	my $temp = shift;
	my $chn = shift;
	if ( defined ($pname) ) {
		if (-f "$temp/$pname") {
			system("su - build -c 'mock -r $chn $temp/$pname &>/dev/null'");
		}
	}
}

##
## cleanup()
##
sub cleanup {
	my $mock_chn = shift;
	my $pname = shift;
	my $temp = shift;
	if (-f '/etc/mock/'.$mock_chn.'.cfg') {
		unlink ('/etc/mock/'.$mock_chn.'.cfg')
	}
	if ( defined ($pname) ) {
		if (-f "$temp/$pname") {
			unlink("$temp/$pname");
		}
	}
	if (-d "/var/lib/mock/$mock_chn") {
		system("rm -rf /var/lib/mock/$mock_chn");
	}
	if (-d "/var/cache/mock/$mock_chn") {
		system("rm -rf /var/cache/mock/$mock_chn");
	}
}

##
## gpattr()
##
sub gpattr {
	my $pname = shift;
	my $temp = shift;
	my $py = shift;

	my $pattr = undef;
	if (defined ($pname) ) {
		if ( (-f "$temp/$pname") && (-f "./$py") ) {
			$pattr = `python $py $temp/$pname`;
			my @arr = split /\s/, $pattr;
			$pattr = join '/', @arr;
		}
	}
	return $pattr;
}

##
## cgen_name()
##
sub cgen_name {
	srand (time ^ $$ ^ unpack "%L*", `ps axww | gzip -f`);
	my $rnd = 0;
	while(1) {
		unless (-f "/etc/mock/cgen_$rnd.cfg") {
			$rnd = int(rand(1_000_000_000_000_000));
			last;
		}
	}
	return "cgen_$rnd";
}

##
## cprez()
##
sub cprez {
	my $out = shift;
	my $mock_chn = shift;
	my $pname = shift;
	my $pattr = shift;
	my $temp = shift;

	if (defined($pattr) && defined ($out) ) {
		unless ( -d "$out/$pattr") {
			system("mkdir -p $out/$pattr");
		}
		unless ( -d "$out/$pattr/SRPMS" ) {
			system("mkdir -p $out/$pattr/SRPMS");
		}
	}

	#say "[cprez] $out/$pattr";
	my $check = undef;
	if (-d "/var/lib/mock/$mock_chn/result") {
		$check = `ls /var/lib/mock/$mock_chn/result/ |grep \.rpm`;

		system("yes | cp -a /var/lib/mock/$mock_chn/result/* $out/$pattr/ &>/dev/null");
		system("su -c 'chroot 2>/dev/null /var/lib/mock/$mock_chn/root rpm -qa | sort > $out/$pattr/rpms.log '");
		system("yes | mv $temp/$pname $out/$pattr/SRPMS/ &>/dev/null");
		system("chmod -R 755 $out/$pattr && restorecon -r $out/$pattr");
	}

	return $check;
}

##
## main()
##
sub main {
	
	my $temp = "/tmp";
	my $out = "/tmp/results";
	my $pl_make_mock_config = 'gen_config.pl';
	my $py_get_rpm_attr = 'get_rpm_attr.py';
	my $url_pname = $ARGV[0];

	my $mock_chn = cgen_name();
	cgen ( $mock_chn, \@repos, $pl_make_mock_config );
	my $pname = pget ( $url_pname, $temp );
	my $pattr = gpattr ($pname, $temp, $py_get_rpm_attr);

	pbuild($pname, $temp, $mock_chn);
	my $stat = cprez ($out, $mock_chn, $pname, $pattr, $temp);
	if ($stat) {
		say "OK";
	}

	cleanup($mock_chn, $pname, $temp);
}
