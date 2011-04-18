#!/usr/bin/perl

##
#   (c) Denis Usanov 2011 :>
##

use utf8;
use strict;
use warnings;
use Audio::Scrobbler;
use MP3::Info;
use Cwd qw(abs_path cwd);
use Getopt::Long;

binmode STDOUT, ":utf8";

my $login;
my $password;
my $dir;
my $timeout     = 60;
my $help        = 0;
my $request_count = 25;
my $count = 0;

sub show_help
{
print <<HELP;
Usage ./$0 -u <user> -p <password> -d <directory_or_file> [-t timeout] [-help]
The script scrobbles random file from the directory (it may use a single file)
with a specified interval.
-u <user>           - your login on las.fm
-p <password>       - your password on last.fm
-d <directory>      - path to directory with mp3 files to scrobble. 
                      You can specify a signle file
-t <delay>          - an interval. Default value is 60 seconds
-h --help           - this text :>
(c) Denis Usanov 2011
HELP
    die("\n");
}


sub random_file
{
    my ($name) = @_;

    if (-d $name)
    {
        chdir $name;
        my @all_files = grep {!/^\.\.?$/} <*>;
        my $rand_file = $all_files[int(rand(scalar @all_files))];
        return random_file($rand_file);
    } 
    else
    {
        return abs_path($name);
    }
}


GetOptions(
    'user=s'        => \$login,
    'password=s'    => \$password,
    'dir=s'         => \$dir,
    't=i'           => \$timeout,
    'help'          => \$help,
) or show_help;

if ($help || !defined $login || !defined $password || !defined $dir)
{
    show_help();
}

while (1)
{
    my $connect = new Audio::Scrobbler(
	    cfg => {
		    progname	=> 'tst',
		    progver		=> '1.4',
		    username	=> $login,
		    password	=> $password,
		    verbose		=> 0,
	    }
    );

    my $ua = $connect->get_ua();

    my $hs = $connect->handshake() or next and print "Error while connecting to last.fm: ".$connect->err;

    print "Connected to last.fm, starting scrobbling with interval ", $timeout, " seconds\n";
    print "Press Ctrl+C to terminate\n";
    
    while (1)
    {
        my $workdir = cwd();
        my $mp3file = random_file($dir);
        chdir $workdir;
        my $tags = get_mp3tag($mp3file) or next;
        my $info = get_mp3info($mp3file) or next;
        my ($title, $artist, $album, $length) = ($tags->{TITLE}, $tags->{ARTIST}, $tags->{ALBUM}, $info->{MM}*60 + $info->{SS});
        
        my $submit = $connect->submit(
            {
	            title	=> $title,
	            artist	=> $artist,
	            album	=> $album,
	            length	=> $length,
            }
        ) or last and print "Error while submitting: ".$connect->err;
        $count++;
        print "$count: '$artist - $title' has been scrobbled\n";
        sleep($timeout);
        last if $count % $request_count == 0;
    }
    print "Already sent $count requests, reconnecting...\n";
}
