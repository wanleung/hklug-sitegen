#!/usr/bin/perl

use strict;
use warnings;
use File::Copy;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use XML::Feed;
use Data::Dumper;

use DateTime::Format::Strptime;

our $data_path = "$Bin/../data/news";
our $template = "$Bin/../TEMPLATE.txt";

my $news_feed_hash = { 
                         'Open Source Hong Kong' => 'http://opensource.hk/rss.xml',
                     };

sub get_feed {
    my ($feed_name, $feed_url) = @_;
    my $feed = XML::Feed->parse(URI->new($feed_url))
        or die XML::Feed->errstr;
    print $feed->title, "\n";
    for my $entry ($feed->entries) {
        create_post($feed_name, $entry->{'entry'});
    }

}

sub create_post {
    my ($feed_name, $entry) = @_;

    print Dumper($entry);

    my $parser = DateTime::Format::Strptime->new(
        pattern => '%a, %d %b %Y %H:%M:%S %z',
        on_error => 'croak',
    );

    my $title = $entry->{'title'};

    my $author = $entry->{'dc'}->{'creator'} . " ($feed_name)";
    
    my $content = 'News Feed - Source :  ' . "\n" . '[' . $feed_name . ' - ' . $title .'](' . $entry->{'link'} . ')' . "\n\n"; 
    $content .= $entry->{'description'};

    my $dt = $parser->parse_datetime($entry->{'pubDate'});

    my $year   = $dt->year;
    my $month  = $dt->month;          # 1-12
    my $day    = $dt->day;            # 1-31
    my $hour   = $dt->hour;           # 0-23
    my $minute = $dt->minute;         # 0-59
    my $second = $dt->second;         # 0-61

    my $ymd1    = $dt->ymd;           # 2002-12-06
    my $ymd2    = $dt->ymd(''); 

    my $hms1    = $dt->hms;           # 14:02:29
    my $hms2    = $dt->hms('');      # 14!02!29

    my $datefile = "$ymd2-$hms2";
    my $date = "$ymd1 $hms1";
    #copy("$template", "$data_path/$datefile.txt");
    #system('/usr/bin/perl', '-p', '-i', '-e', '"s/\[%DATE\]/'.$date.'/g"', "$data_path/$datefile.txt");
    open FILEIN, "<:utf8", $template;
    open FILEOUT, ">:utf8", "$data_path/$datefile.txt";
    while (<FILEIN>) {
        my $line = $_;
        $line =~ s/\[%DATE\]/$date/;
        $line =~ s/\[%AUTHOR\]/$author/;
        $line =~ s/\[%TITLE\]/$title/;
        $line =~ s/\[%CONTENT\]/$content/; 
        print $line;
        print FILEOUT $line;
    }
    close FILEIN;
    close FILEOUT;
}

sub main {
    for my $feed_key (keys $news_feed_hash) {
        get_feed($feed_key, $news_feed_hash->{$feed_key});
    }
}

main();

