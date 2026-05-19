#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Template;
use YAML::Tiny;
use File::Path qw(make_path);

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Sitegen::DataLoader qw(load_data load_announce);
use Sitegen::Cache      qw(load_cache save_cache is_fresh update_cache);
use Sitegen::SEO        qw(seo_meta);
use Sitegen::Tags       qw(collect_tags gen_tag_pages);

my $force = 0;
GetOptions('force' => \$force);

our $base_dir       = "$Bin/..";
our $data_dir       = "$base_dir/data";
our $top_dir        = "$data_dir/top";
our $news_dir       = "$data_dir/news";
our $site_folder    = "$base_dir/site";
our $archive_folder = "$site_folder/archive";
our $cache_file     = "$data_dir/.sitegen-cache.json";
our $config_file    = "$data_dir/sitegen.yaml";

=head1 NAME

sitegen.pl - Static site generator for HKLUG

=head1 SYNOPSIS

  perl bin/sitegen.pl [--force]

=head1 DESCRIPTION

Generates the HKLUG static site from .txt source files.  With C<--force> all
pages are rebuilt regardless of cache; without it, archive posts whose source
file has not changed are skipped.

=cut

sub tt_process {
    my ($tt, $template, $vars, $outfile) = @_;
    open(my $fh, '>:encoding(UTF-8)', $outfile) or die "Cannot open $outfile: $!";
    $tt->process($template, $vars, $fh) or die $tt->error();
    close $fh or die "Cannot write $outfile: $!";
}

sub load_config {
    die "Missing config file: $config_file\n" unless -f $config_file;
    open(my $fh, '<:encoding(UTF-8)', $config_file) or die "Cannot open $config_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    my $yaml = YAML::Tiny->read_string($content)
        or die "Cannot parse $config_file: " . YAML::Tiny->errstr . "\n";
    return $yaml->[0];
}

sub main {
    my $config = load_config();
    my $cache  = $force ? {} : load_cache($cache_file);

    my $tt = Template->new({
        INCLUDE_PATH => "$base_dir/template",
        INTERPOLATE  => 0,
    }) || die "$Template::ERROR\n";

    make_path($site_folder, $archive_folder);

    gen_home($tt, $config);
    gen_pages($tt, $config);
    my $all_posts = gen_archive($tt, $config, $cache);
    gen_tags($tt, $config, $all_posts);

    save_cache($cache_file, $cache);
    print "Done.\n";
}

=head2 gen_home($tt, $config)

Renders the site homepage (C<index.html>) from the five most recent news posts.

=cut

sub gen_home {
    my ($tt, $config) = @_;
    my @filelist;
    opendir(my $dh, $news_dir) or die $!;
    while (my $file = readdir($dh)) { push @filelist, $file if $file =~ m/\.txt$/ }
    closedir($dh);
    my @sortlist = sort @filelist;
    my $total    = scalar @sortlist;

    my @news_posts;
    for my $i (1..5) {
        last if ($total - $i < 0);
        push @news_posts, load_data("$news_dir/$sortlist[$total - $i]");
    }

    my $announce = load_announce($top_dir);
    my $seo_post = { title => $config->{site_name} . ' > News', content => '' };
    tt_process($tt, 'news.html', {
        title    => $config->{site_name} . ' > News',
        news     => \@news_posts,
        announce => $announce,
        seo      => seo_meta($seo_post, $config, '/'),
    }, "$site_folder/index.html");
}

=head2 gen_pages($tt, $config)

Renders static .txt pages in the data root directory into C<site/>.

=cut

sub gen_pages {
    my ($tt, $config) = @_;
    my @filelist;
    opendir(my $dh, $data_dir) or die $!;
    while (my $file = readdir($dh)) { push @filelist, $file if $file =~ m/\.txt$/ }
    closedir($dh);

    for my $file (@filelist) {
        my $post     = load_data("$data_dir/$file");
        my $announce = load_announce($top_dir);
        (my $newfile = $file) =~ s/\.txt$/.html/;
        tt_process($tt, 'page.html', {
            title    => $config->{site_name} . ' > ' . $post->{title},
            post     => $post,
            announce => $announce,
            seo      => seo_meta($post, $config, "/$newfile"),
        }, "$site_folder/$newfile");
    }
}

=head2 gen_archive($tt, $config, $cache)

Renders individual archive post pages (with incremental cache) and the archive
list page.  Returns an arrayref of all posts, newest-first, for use by
C<gen_tags>.

=cut

sub gen_archive {
    my ($tt, $config, $cache) = @_;
    my @filelist;
    opendir(my $dh, $news_dir) or die $!;
    while (my $file = readdir($dh)) { push @filelist, $file if $file =~ m/\.txt$/ }
    closedir($dh);

    my @sortlist = sort @filelist;
    my $total    = scalar @sortlist;
    my (@allnews, $count);
    $count = 0;

    for my $file (@sortlist) {
        (my $newfile = $file) =~ s/\.txt$/.html/;
        my $srcfile = "$news_dir/$file";
        my $outfile = "$archive_folder/$newfile";

        my $post = load_data($srcfile);
        $post->{url} = "/archive/$newfile";
        push @allnews, $post;

        if (!$force && is_fresh($cache, $srcfile, $outfile)) {
            print "SKIP $file\n";
            $count++;
            next;
        }

        my $previndex = ($count - 1 < 0)        ? 0           : $count - 1;   # older post
        my $nextindex = ($count + 1 >= $total)  ? $total - 1  : $count + 1;   # newer post

        (my $prevfile = $sortlist[$previndex]) =~ s/\.txt$/.html/;
        (my $nextfile = $sortlist[$nextindex]) =~ s/\.txt$/.html/;
        (my $startfile = $sortlist[$total - 1]) =~ s/\.txt$/.html/;
        (my $endfile   = $sortlist[0])          =~ s/\.txt$/.html/;

        tt_process($tt, 'archive.html', {
            title => $config->{site_name} . ' > Archive > ' . $post->{title},
            post  => $post,
            url   => {
                front     => "/archive/$startfile",
                end       => "/archive/$endfile",
                prev      => "/archive/$prevfile",
                next      => "/archive/$nextfile",
                home      => "/archive/",
                hometitle => "Archive",
            },
            seo => seo_meta($post, $config, "/archive/$newfile"),
        }, $outfile);
        print "GEN $file\n";

        update_cache($cache, $srcfile);
        $count++;
    }

    # Archive list — always regenerate
    my @newest_first = reverse @allnews;
    my $announce  = load_announce($top_dir);
    my $seo_post  = { title => $config->{site_name} . ' > Archive', content => '' };
    tt_process($tt, 'archive_list.html', {
        title     => $config->{site_name} . ' > Archive',
        pagetitle => 'Archives',
        news      => \@newest_first,
        announce  => $announce,
        seo       => seo_meta($seo_post, $config, '/archive/'),
    }, "$archive_folder/index.html");

    return \@newest_first;  # newest-first for tags
}

=head2 gen_tags($tt, $config, $all_posts)

Collects tags from all posts and renders C<site/tags/index.html> and
C<site/tags/E<lt>slugE<gt>/index.html> for each tag.

=cut

sub gen_tags {
    my ($tt, $config, $all_posts) = @_;
    my $announce = load_announce($top_dir);
    my $tags = collect_tags(@$all_posts);
    gen_tag_pages($tt, $tags, $site_folder, $config, $announce);
}

main();
