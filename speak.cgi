#!/usr/bin/perl
#
# CGI script to bridge eSpeak TTS to the Web - WebAnywhere.
#
# @copyright (c)2008 University of Washington.
# @license http://www.opensource.org/licenses/bsd-license.php
# @source  http://code.google.com/p/webanywhere/#trunk/tts/espeak/getsound.pl#r264
# Modifications, Nick Freear {http://freear.org.uk}
#
use strict;
use warnings;
use utf8;
use CGI qw(:standard unescape);
use Digest::MD5;
use File::Path;
use Encode;

# Paths - edit me.
my $pico2wave= '/usr/bin/pico2wave';
my $aplay    = '/usr/bin/aplay';
my $log_dir= '/tmp';  #'/Applications/MAMP/logs';
my $request_log= "$log_dir/speak_request.log"; #'/var/log/ekho/espeak.request';
my $error_log  = "$log_dir/speak_error.log";   #'/var/log/ekho/espeak.error';
#my $cache_dir = '/var/cache/sounds';  #'/Applications/MAMP/tmp/cache_sounds';
my $cache_dir = '/tmp';  #'/Applications/MAMP/tmp/cache_sounds';

my $ext = 'wav'; #NDF.

my $voice = 'en-US';
my $cache = 1;
my $text = param('text');
#error("Woops, parameter 'text=X' is required.") if !$text; #NDF. Added.
  $text = "Error. Parameter text is required." if !$text;
$voice = param('lang') if (defined param('lang'));
$cache = param('cache') if (defined param('cache'));

$voice =~ s/\|/+/;  #NDF. en%2Bf1.
$text = unescape($text);

# handle encoding
#`echo "raw: $text" >> /tmp/espeak.log`;
# decode MS %u infamous non-standard encoding in URL
while ($text =~ /([^%]*)%u(....)(.*)/) {
  $text = $1 . chr(hex("0x$2")) . $3;
}
$text =~ s/^\s+//; # delete leading spaces
$text =~ s/\s+$//; # delete tailing spaces
$text =~ s/\"//g;
#`echo "speaking $text" >> /tmp/espeak.log`;

logRequest($text, $voice);
#sendFileToClient(getMp3File($text, $voice, $ext), $text, $voice, $ext);
playvoice($text, $voice, $ext);

##### END OF MAIN #####
sub playvoice {
  my ($text, $voice, $ext) = @_;
  
  # Constructs a filename based on the MD5 of the text.
  my $md5 = Digest::MD5->new;
  $md5->add(encode_utf8($text));
  my $filename = $md5->b64digest;
  $filename =~ s/[\/+\s]/_/g;
  my $lc_filename = lc($filename);

  my $first_dir = substr($lc_filename, 0, 1);
  my $second_dir = substr($lc_filename, 1, 1);
  my $third_dir = substr($lc_filename, 2, 1);

  #my $enc_voice = $voice; #NDF. Encode '+m3' etc.
  #$enc_voice =~ s/\+/_/;
  my $final_dir = "$cache_dir/speak-$voice/$first_dir/$second_dir/$third_dir";
  my $final_filename = "$final_dir/$filename.$ext"; #NDF. Was .mp3.

  # Ensure that the final directory actually exists.
  mkpath $final_dir;

  if((!(-e $final_filename)) || $cache == 0) {
	system("$pico2wave -l $voice -w $final_filename \"$text\" ");
  }

  system("$aplay -q $final_filename");
  print "OK\n";
}

# global variable: $request_log
sub logRequest {
  my ($text, $voice) = @_;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  if (-s $request_log > 1000000) {
    for (my $i = 4; $i > 0; --$i) {
      if (-e "$request_log.$i") {
        rename("$request_log.$i", "$request_log." . ($i + 1));
      }
    }
    rename($request_log, "$request_log.1");
  }
  open(REQUEST_LOG, '>>', $request_log);
  printf REQUEST_LOG "[%4d%02d%02d-%02d:%02d:%02d] [%s] %s\n",
         1900 + $year, $mon, $mday, $hour, $min, $sec, $voice, $text;
  close(REQUEST_LOG);
}

sub error() {
  my $error = shift;

  open(ERROR_LOG, '>>', "$error_log");
  print ERROR_LOG "$error\n";
  close(ERROR_LOG);

  print "Status: 400 Bad Request\n";
  #print "Status: 500 Internal Server Error\n"; #NDF.?
  print "Content-type: text/html\n\n";
  print "ERROR: " . $error;

  exit(0);
}

1;
