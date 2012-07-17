#!/usr/bin/perl
use strict;
use warnings;
use Template;
use Data::Dumper;

use FindBin qw($Bin);
use lib "$Bin/../lib";

our $data_dir = "$Bin/../data";
our $top_dir = "$data_dir/top";
our $news_dir = "$data_dir/news";
our $site_name = 'Hong Kong Linux User Group - 香港Linux用家協會(HKLUG)';
our $site_folder = "$Bin/../site";
our $archive_folder = "$site_folder/archive";

sub main {
    my $tt = Template->new({
        INCLUDE_PATH => "$Bin/../template",
        INTERPOLATE  => 1,
    }) || die "$Template::ERROR\n";
    
    gen_home($tt);
    gen_pages($tt);
    gen_archive($tt);
}

sub gen_home {
    my ($tt) = @_;
    my @filelist;
    opendir(DIRIN, $news_dir) or die $!;
    while (my $file = readdir(DIRIN)) {
        if ($file =~ m/\.txt$/) {
            push @filelist, $file;
        }
    }
    closedir(DIRIN);
    my @sortlist = sort @filelist;
    
    my $total = @sortlist;

    my @news_posts;
    for my $i (1..5) {
        last if ($total - $i < 0);
        my $post = load_data("$news_dir/$sortlist[$total - $i]");
        print Dumper($post);
        push @news_posts, $post; 
    } 

    my $announce = load_announce();

    my $vars = {
        title => "$site_name \&gt News",
        news => \@news_posts,
        announce => $announce,
    };

    print Dumper($vars);

    $tt->process('news.html', $vars, "$site_folder/index.html")
        || die $tt->error(), "\n";
}

sub gen_pages {
    my ($tt) = @_;
    my @filelist;
    opendir(DIRIN, $data_dir) or die $!;
    while (my $file = readdir(DIRIN)) {
        if ($file =~ m/\.txt$/) {
            push @filelist, $file;
        }
    }
    closedir(DIRIN);

    for my $file (@filelist) {
        my $post = load_data("$data_dir/$file");
        print Dumper($post);

        my $announce = load_announce();
        my $vars = {
            title => "$site_name \&gt ".$post->{title},
            post => $post,
            announce => $announce,
        };

        print Dumper($vars);

        my $newfile = $file;
        $newfile =~ s/\.txt/\.html/g;
        print "$newfile \n";
        $tt->process('page.html', $vars, "$site_folder/$newfile")
            || die $tt->error(), "\n";
    }
}

sub gen_archive {
    my ($tt) = @_;
    my @filelist;
    opendir(DIRIN, $news_dir) or die $!;
    while (my $file = readdir(DIRIN)) {
        if ($file =~ m/\.txt$/) {
            push @filelist, $file;
        }
    }
    closedir(DIRIN);

    my @sortlist = sort @filelist;
    my $total = @sortlist;

    my $count = 0;

    my @allnews;

    for my $file (@sortlist) {
        my $post = load_data("$news_dir/$file");
        print Dumper($post);

        my $newfile = $file;
        $newfile =~ s/\.txt/\.html/g;

        my $startfile = $sortlist[$total-1];
        my $endfile = $sortlist[0];

        my $preindex = $count+1;
        if ($count+1 >= $total) {
            $preindex = $count;
        } 

        my $nextindex = $count-1;
        if ($count-1 < 0) {
            $nextindex = 0;
        }

        my $prevfile = $sortlist[$preindex];
        my $nextfile = $sortlist[$nextindex];

        $startfile =~ s/\.txt/\.html/g;
        $endfile =~ s/\.txt/\.html/g;
        $prevfile =~ s/\.txt/\.html/g;
        $nextfile =~ s/\.txt/\.html/g;

        my $vars = {
            title => "$site_name \&gt Archive \&gt ".$post->{title},
            post => $post,
            url => { 
                front => "/archive/$startfile",
                end => "/archive/$endfile",
                prev => "/archive/$prevfile",
                next => "/archive/$nextfile",
                home => "/archive/",
                hometitle => "Archive",
            },
        };

        $post->{url} = "/archive/$newfile";
        push @allnews, $post;

        print Dumper($vars);

        print "$newfile \n";
        $tt->process('archive.html', $vars, "$archive_folder/$newfile")
            || die $tt->error(), "\n";

        $count ++;
    }

    my @revesenews;
    while (my $post = pop(@allnews) ) {
        push @revesenews, $post;
    }
    print Dumper(\@revesenews);
    my $announce = load_announce();
    my $vars = {
            title => "$site_name \&gt Archive",
            pagetitle => "Archives",
            news => \@revesenews,
            announce => $announce,
        };
    print Dumper($vars);
    $tt->process('archive_list.html', $vars, "$archive_folder/index.html")
            || die $tt->error(), "\n";
}

sub load_data {
    my ($filename) = @_;
    print "$filename\n";
    my %post;

    my $iscontent = 0;

    open (FILEIN, "<$filename");
    while (<FILEIN>) {
        my $line = $_;
        if ($line =~m/^\/\//) {
            next;
        }
        if ($iscontent == 0) {
            chomp $line;
            if ($line =~m/^Date:.*/) {
                my ($key, $value) = split /:/, $line, 2;
                $post{date} = trim($value); 
            } 
            if ($line =~m/^Author:.*/) {
                my ($key, $value) = split /:/, $line, 2;
                $post{author} = trim($value);
            } 
            if ($line =~m/^Title:.*/) {
                my ($key, $value) = split /:/, $line, 2;
                $post{title} = trim($value);
            }
            if ($line =~m/^Content:.*/) {
                my ($key, $value) = split /:/, $line, 2;
                $post{content} = $value;
                $iscontent = 1;
            }
        } else {
           $post{content} .= $line; 
        }
    };
    close FILEIN;
    return \%post;
}

sub load_announce {
    my @filelist;
    opendir(DIRIN, $top_dir) or die $!;
    while (my $file = readdir(DIRIN)) {
        if ($file =~ m/\.txt$/) {
            push @filelist, $file;
        }
    }
    closedir(DIRIN);
    my @sortlist = sort @filelist;
    my $filename = pop @sortlist;

    return load_data("$top_dir/$filename");
}

sub trim {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

main();

__END__
my $tt = Template->new({
    INCLUDE_PATH => '../template',
    INTERPOLATE  => 1,
}) || die "$Template::ERROR\n";

my $vars = {
    title     => 'Count Edward van Halen',
    debt     => '3 riffs and a solo',
    deadline => 'the next chorus',
    news => [{"title" => "aaa", content=>"ldsuifsd", "author" =>"bbb"} , {"title" =>"1111", content=>"87sdfsdfs", "author" =>"222"} ,

    ],
    post => {title=>'aaa', author=>'bbb'
    },
};

$tt->process('news_section.html', $vars)
    || die $tt->error(), "\n";
