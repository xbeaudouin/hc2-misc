#!/usr/bin/perl -w

use CGI;
use strict;
use warnings;

###
# donne l'@ ip, dns, arp en fonction du dns OU de l'ip
sub check_host {
   my $param_ip_or_host = shift;

   my %ret = (
      ipv4_address => '0.0.0.0',
      mac_address  => 'unknown',
      );

   my $cmd = "/usr/sbin/arp -a | grep  -e \"".$param_ip_or_host."\" | head -1";
   my $cmd_arpwatch = `$cmd`;
   chomp $cmd_arpwatch;
   #my ($arp, $ip, $timestamp, $host) = split /\s+/, $cmd_arpwatch;
   my ($host, $ip, $bof, $arp ) = split /\s+/, $cmd_arpwatch;
#print "OOO $cmd\n";
#print "OUT $cmd_arpwatch\n";
#print "TTT arp $arp -> $ip pour host $host\n";
   $ip =~ s/\(//g;
   $ip =~ s/\)//g;
   $ret{ipv4_address} = $ip        if $ip;
   $ret{mac_address}  = $arp       if $arp;

   print "{\"hostname\":\"$param_ip_or_host\",\"ipv4\":\"$ret{ipv4_address}\",\"MAC\":\"$ret{mac_address}\"}\n";
   return %ret;
   }


my $req = new CGI;
print $req->header(-type => 'application/json', -expires => '+10m');
if ($req->param('host') eq "") {
	print "{ }";
}
else {
	check_host($req->param('host'));
}
#my %stuff = check_host("ikiwi");

