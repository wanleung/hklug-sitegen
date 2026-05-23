#!/usr/bin/perl

use strict;
use warnings;
use File::Copy;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use XML::Feed;
use Data::Dumper;
use HTTP::Tiny;
use File::Path qw(make_path);

use DateTime::Format::Strptime;

# Fetch the og:image from a URL and save it to static/images/<slug>.<ext>.
# Returns the relative path "images/<slug>.<ext>" on success, or undef on failure.
sub fetch_og_image {
    my ($url, $slug) = @_;
    my $ua = HTTP::Tiny->new(timeout => 10);

    # Fetch the article page
    my $resp = $ua->get($url);
    return unless $resp->{success};

    my $html = $resp->{content};

    # Extract og:image — handle both attribute orderings
    my ($og_url) = ($html =~ /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i);
    unless ($og_url) {
        ($og_url) = ($html =~ /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i);
    }
    return unless $og_url;

    # Download the image
    my $img_resp = $ua->get($og_url);
    return unless $img_resp->{success};

    my $ct = $img_resp->{headers}{'content-type'} // '';
    return unless $ct =~ m{^image/};

    my $ext = $ct =~ /jpeg|jpg/i ? 'jpg'
            : $ct =~ /png/i      ? 'png'
            : $ct =~ /gif/i      ? 'gif'
            : $ct =~ /webp/i     ? 'webp'
            :                      'jpg';

    my $img_dir = "$Bin/../static/images";
    make_path($img_dir);

    my $img_file = "$img_dir/$slug.$ext";
    open(my $fh, '>:raw', $img_file) or return;
    print $fh $img_resp->{content};
    close $fh;

    return "images/$slug.$ext";
}

our $data_path = "$Bin/../data/top";
our $template = "$Bin/../TEMPLATE.txt";

our $news_feed_hash = { 
                         'Open Source Hong Kong' => 'https://opensource.hk/feed/',
			 'Hong Kong Open Source Conference' => 'https://info.hkoscon.org/feed/',
                     };

our $new_feed_home_hash = {
                             'Open Source Hong Kong' => 'https://opensource.hk',
			     'Hong Kong Open Source Conference' => 'https://info.hkoscon.org',
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

    my $url = $new_feed_home_hash->{$feed_name};
    $content =~ s/\<img src=\"\//\<img src=\"$url\//g;
    $content =~ s/href=\"\//href=\"$url\//g;

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

    # Try to fetch OG image from the article source URL
    my $image_line = '';
    if (my $img_rel = fetch_og_image($entry->{'link'}, $datefile)) {
        $image_line = "Image: $img_rel";
        print "  Fetched OG image: $img_rel\n";
    }
    #copy("$template", "$data_path/$datefile.txt");
    #system('/usr/bin/perl', '-p', '-i', '-e', '"s/\[%DATE\]/'.$date.'/g"', "$data_path/$datefile.txt");
    open FILEIN, "<:utf8", $template;
    open FILEOUT, ">:utf8", "$data_path/$datefile.txt";
    while (<FILEIN>) {
        my $line = $_;
        $line =~ s/\[%DATE\]/$date/;
        $line =~ s/\[%AUTHOR\]/$author/;
        $line =~ s/\[%TITLE\]/$title/;
        $line =~ s/\[%IMAGE\]/$image_line/;
        $line =~ s/\[%CONTENT\]/$content/; 
        print $line;
        print FILEOUT $line;
    }
    close FILEIN;
    close FILEOUT;
}

sub main {
    for my $feed_key (keys %$news_feed_hash) {
        get_feed($feed_key, $news_feed_hash->{$feed_key});
    }
}

main();

