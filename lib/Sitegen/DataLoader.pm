package Sitegen::DataLoader;

use strict;
use warnings;
use Exporter 'import';
use Text::Markdown::Discount qw(markdown);

our @EXPORT_OK = qw(load_data load_announce);

sub load_data {
    my ($filename) = @_;
    my %post;
    my $iscontent = 0;

    open(my $fh, '<', $filename) or die "Cannot open $filename: $!";
    while (my $line = <$fh>) {
        next if $line =~ m|^//|;
        if ($iscontent == 0) {
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
                $iscontent = 1;
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
    my @sortlist = sort @filelist;
    my $filename = pop @sortlist;
    return load_data("$top_dir/$filename");
}

1;
