#!/usr/bin/perl
use warnings FATAL => qw(all);
use strict;
use Data::Dump qw(dump pp);
use JSON::PP;
use LWP;
use LWP::UserAgent;

my $num_args = $#ARGV + 1;
if ($num_args !=3) {
	die "\nUsage: temp.pl ip/host user pass\n";
}
my $host = $ARGV[0];
my $user = $ARGV[1];
my $passw= $ARGV[2];

my $ua = LWP::UserAgent->new;
$ua->agent("KiwiApp/0.1");

my $req = HTTP::Request->new (GET => 'http://'.$user.':'.$passw.'@'.$host.'/api/devices?id=3');

my $res = $ua->request($req);

#if ok
if ($res->is_success) {
	my $j = JSON::PP->new;
	my $d = $j->decode($res->content);

	#pp($d);

	print $d->{properties}->{Wind}."\n";
}
else {
	print "NaN\n";
}
print "0\n";
print "meteo wind\n";
