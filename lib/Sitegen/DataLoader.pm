package Sitegen::DataLoader;

use strict;
use warnings;
use utf8;
use Exporter 'import';
use Text::Markdown::Discount qw(markdown);
use File::Basename qw(basename);

our @EXPORT_OK = qw(load_data load_announce);

sub load_data {
    my ($filename) = @_;
    my %post;
    my $in_content = 0;

    open(my $fh, '<:encoding(UTF-8)', $filename) or die "Cannot open $filename: $!";
    while (my $line = <$fh>) {
        if ($in_content == 0) {
            next if $line =~ m|^//|;
            chomp $line;
            if    ($line =~ m/^Date:\s*(.+)$/)   { $post{date}   = $1 }
            elsif ($line =~ m/^Author:\s*(.+)$/)  { $post{author} = $1 }
            elsif ($line =~ m/^Title:\s*(.+)$/)   { $post{title}  = $1 }
            elsif ($line =~ m/^Tags:\s*(.*)$/) {
                my $raw = $1;
                my @raw_tags =
                    map  { my $t = $_; $t =~ s/^\s+|\s+$//g; lc $t }
                    grep { /\S/ }
                    split(/,/, $raw);
                my @valid_tags;
                for my $t (@raw_tags) {
                    if ($t =~ m{[/\\]|\.\.}) {
                        warn "Skipping unsafe tag '$t' in $filename\n";
                    } else {
                        push @valid_tags, $t;
                    }
                }
                $post{tags} = \@valid_tags;
            }
            elsif ($line =~ m/^Content:(.*)$/) {
                $post{content} = $1;
                $in_content = 1;
            }
        } else {
            $post{content} .= $line;
        }
    }
    close $fh;

    $post{tags}    //= [];
    $post{content}   = markdown($post{content} // '');

    # slug: filename stem without extension
    (my $slug = basename($filename)) =~ s/\.txt$//;
    $post{slug} = $slug;

    # excerpt: strip HTML tags, collapse whitespace, truncate to 180 chars
    (my $plain = $post{content}) =~ s/<[^>]+>//g;
    $plain =~ s/\s+/ /g;
    $plain =~ s/^\s+|\s+$//g;
    $post{excerpt} = length($plain) > 180 ? substr($plain, 0, 180) . '...' : $plain;

    return \%post;
}

sub load_announce {
    my ($top_dir, $config) = @_;
    $config //= {};
    my $max = $config->{max_announces} // 3;

    opendir(my $dh, $top_dir) or die "Cannot open $top_dir: $!";
    my @files = sort grep { /\.txt$/ } readdir($dh);
    closedir($dh);

    # Return the most recent $max announcements (files are date-named, sort desc)
    my @recent = @files > $max ? @files[-$max .. -1] : @files;
    my @latest = map { load_data("$top_dir/$_") } reverse @recent;
    return \@latest;
}

=head1 NAME

Sitegen::DataLoader - Parse hklug-sitegen .txt article files

=head1 SYNOPSIS

  use Sitegen::DataLoader qw(load_data load_announce);

  my $post = load_data('/path/to/article.txt');
  # Returns hashref with keys: date, author, title, tags (arrayref), content (HTML)

  my $latest = load_announce('/path/to/top/');
  # Returns arrayref of post hashrefs for enabled sources.
  # Respects config->{announcements}{hklug|oshk|hkoscon} flags (default: all true).
  # HKLUG: lexicographically latest dated .txt file.
  # OSHK:  oshk-latest.txt (written by ai-it-press workflow).
  # HKOSCon: hkoscon-latest.txt (written by ai-it-press workflow).

=head1 DESCRIPTION

Parses hklug-sitegen article files with the following format:

  Date: 2024-01-15
  Author: Your Name
  Title: Article Title
  Tags: tag1, tag2
  Content:
  Article body in Markdown format.

Comments prefixed with C<//> are stripped from the header section only.
The content body is parsed as Markdown and returned as HTML.

=cut

1;
