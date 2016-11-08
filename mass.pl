#!/usr/bin/perl
use 5.010;
use strict;
use warnings;
use Config::YAML;
use Data::Dumper;
use threads;
use threads::shared;
use constant THREADS_NUM => 4;
use dbv;

my $config = Config::YAML->new( config => 'config.yaml' );
my $url = $config->{'wsrc'};

=pod
my $blist = $config->{'blist'};
open FILE, "<$blist";
my @blist = <FILE>;
close FILE;
chomp @blist;

foreach(@blist) {
	my @attr = ($_, "", '');
	my $dbv = dbv->new();
        $dbv->add_ok(\@attr);
}
exit 1;
=cut

my @srpms :shared = `perl links.pl $url`;
chomp @srpms;

my $dbv = dbv->new();
@srpms = @{ $dbv->get_realy_need(\@srpms) };

my @threads;
for (my $i=1; $i <= ($#srpms+1)/(THREADS_NUM)+1; $i++) {
	@threads = ();
	for my $j (1..THREADS_NUM) {
		if ( $srpms[$i*$j-1] ~~ @{ $dbv->get_realy_need(\@srpms) } ) {
#			say $srpms[$i*$j-1];
			push @threads, threads->create(\&thread_func, $j, $srpms[$i*$j-1]);
		}
	}
	$_->join for(@threads);
}

sub thread_func {
	my $id = shift;
	my $z = shift;
	my $pkg = $z;
	if (defined($pkg)&&($pkg=~/src.rpm/)) {
		$pkg=~s/.*\/(.*.src.rpm)/$1/;
	}
	else {
		return;
	}
	chomp $pkg;
	if (defined($z)) {
		say "$id: $z";
		my $result = `perl run.pl $z`;
		chomp $result;
		my @attr = ($pkg, $z, '');
		my $dbv = dbv->new();
		if ("$result" eq "OK") {
                        $dbv->add_ok(\@attr);
		}
		else {
			$dbv->add_err(\@attr);
		}
	}
}

