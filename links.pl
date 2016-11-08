#!/usr/bin/perl
use 5.010;
use strict;
use warnings;
use WWW::Mechanize;

my $url  = $ARGV[0];

my $mech  = WWW::Mechanize->new();
$mech->get( $url );
my @links = $mech->links();

foreach my $link (@links) {
        if ($link->url() =~ /\.src\.rpm/) {
                print $url.'/'.$link->url()."\n";
        }
}
