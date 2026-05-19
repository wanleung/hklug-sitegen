package Sitegen::DataLoader;

use strict;
use warnings;
use utf8;
use Exporter 'import';
use Text::Markdown::Discount qw(markdown);

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
                $post{tags} = [
                    map  { my $t = $_; $t =~ s/^\s+|\s+$//g; lc $t }
                    grep { /\S/ }
                    split(/,/, $raw)
                ];
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
    return \%post;
}

sub load_announce {
    my ($top_dir) = @_;
    my @filelist;
    opendir(my $dh, $top_dir) or die "Cannot open $top_dir: $!";
    while (my $file = readdir($dh)) {
        push @filelist, $file if $file =~ m/\.txt$/;
    }
    closedir($dh);
    die "No .txt files found in $top_dir\n" unless @filelist;
    my $filename = (sort @filelist)[-1];
    return load_data("$top_dir/$filename");
}

=head1 NAME

Sitegen::DataLoader - Parse hklug-sitegen .txt article files

=head1 SYNOPSIS

  use Sitegen::DataLoader qw(load_data load_announce);

  my $post = load_data('/path/to/article.txt');
  # Returns hashref with keys: date, author, title, tags (arrayref), content (HTML)

  my $latest = load_announce('/path/to/top/');
  # Returns the lexicographically last .txt file parsed as a post

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
