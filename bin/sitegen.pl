#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Template;
use YAML::Tiny;
use File::Path qw(make_path);
use File::Find  qw(find);
use File::Copy  qw(copy);

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
our $announce_folder = "$site_folder/announce";
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
    copy_static();   # copy static/images/ → site/images/
    my $cache  = $force ? {} : load_cache($cache_file);

    my $tt = Template->new({
        INCLUDE_PATH => "$base_dir/template",
        INTERPOLATE  => 0,
        ENCODING     => 'utf8',
    }) || die "$Template::ERROR\n";

    make_path($site_folder, $archive_folder, $announce_folder);

    gen_home($tt, $config);
    gen_pages($tt, $config);
    gen_announcements($tt, $config);
    my $all_posts = gen_archive($tt, $config, $cache);
    gen_tags($tt, $config, $all_posts);
    gen_sitemap($config, $all_posts);

    save_cache($cache_file, $cache);
    print "Done.\n";
}

=head2 copy_static()

Copies C<static/images/> to C<site/images/> before page generation.
Images in C<static/images/> are tracked by git; C<site/images/> is gitignored.

=cut

sub copy_static {
    # Copy static/images/ → site/images/
    my $src = "$base_dir/static/images";
    my $dst = "$base_dir/site/images";
    if (-d $src) {
        make_path($dst);
        find(sub {
            return if -d $_;
            (my $rel = $File::Find::name) =~ s{^\Q$src/}{};
            my $target = "$dst/$rel";
            my $target_dir = $target;
            $target_dir =~ s{/[^/]+$}{};
            make_path($target_dir);
            copy($File::Find::name, $target) or warn "copy_static: cannot copy $File::Find::name: $!";
        }, $src);
    }

    # Copy root-level static files (robots.txt, etc.) → site/
    opendir(my $dh, "$base_dir/static") or return;
    while (my $f = readdir($dh)) {
        next if $f =~ /^\./;
        my $srcfile = "$base_dir/static/$f";
        next unless -f $srcfile;
        copy($srcfile, "$site_folder/$f") or warn "copy_static: cannot copy $srcfile: $!";
    }
    closedir($dh);
}

=head2 gen_home($tt, $config)

Renders the site homepage (C<index.html>) from the eight most recent news posts.

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
    for my $i (1..8) {
        last if ($total - $i < 0);
        my $post = load_data("$news_dir/$sortlist[$total - $i]");
        $post->{url} = "/archive/$post->{slug}.html";
        push @news_posts, $post;
    }

    my $announces = load_announce($top_dir, $config);
    for my $post (@$announces) {
        $post->{url} = "/announce/$post->{slug}.html";
    }

    my $seo_post = { title => $config->{site_name} . ' > News', content => '' };
    tt_process($tt, 'news.html', {
        title     => $config->{site_name} . ' > News',
        news      => \@news_posts,
        announces => $announces,
        seo       => seo_meta($seo_post, $config, '/'),
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
        my $announces = load_announce($top_dir, $config);
        (my $newfile = $file) =~ s/\.txt$/.html/;
        tt_process($tt, 'page.html', {
            title     => $config->{site_name} . ' > ' . $post->{title},
            post      => $post,
            announces => $announces,
            seo       => seo_meta($post, $config, "/$newfile"),
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
    my $announces = load_announce($top_dir, $config);
    my $seo_post  = { title => $config->{site_name} . ' > Archive', content => '' };
    tt_process($tt, 'archive_list.html', {
        title     => $config->{site_name} . ' > Archive',
        pagetitle => 'Archives',
        news      => \@newest_first,
        announces => $announces,
        seo       => seo_meta($seo_post, $config, '/archive/'),
    }, "$archive_folder/index.html");

    return \@newest_first;  # newest-first for tags
}

=head2 gen_announcements($tt, $config)

Renders individual announcement pages and the announcement list page.
Announcements are read from C<data/top/> and output to C<site/announce/>.

=cut

sub gen_announcements {
    my ($tt, $config) = @_;
    my @filelist;
    opendir(my $dh, $top_dir) or die $!;
    while (my $file = readdir($dh)) { push @filelist, $file if $file =~ m/\.txt$/ }
    closedir($dh);

    my @sortlist = sort @filelist;
    my $total    = scalar @sortlist;
    my @all_announces;

    for my $file (@sortlist) {
        my $srcfile = "$top_dir/$file";
        my $post = load_data($srcfile);
        $post->{url} = "/announce/$post->{slug}.html";
        push @all_announces, $post;

        my $outfile = "$announce_folder/$post->{slug}.html";
        tt_process($tt, 'announce_page.html', {
            title => $config->{site_name} . ' > Announcements > ' . $post->{title},
            post  => $post,
            seo   => seo_meta($post, $config, "/announce/$post->{slug}.html"),
        }, $outfile);
        print "GEN announce $file\n";
    }

    # Announcement list — always regenerate
    my @newest_first = reverse @all_announces;
    my $announces = load_announce($top_dir, $config);
    my $seo_post  = { title => $config->{site_name} . ' > Announcements', content => '' };
    tt_process($tt, 'announce_list.html', {
        title     => $config->{site_name} . ' > Announcements',
        pagetitle => 'Announcements',
        posts     => \@newest_first,
        announces => $announces,
        seo       => seo_meta($seo_post, $config, '/announce/'),
    }, "$announce_folder/index.html");
}

=head2 gen_tags($tt, $config, $all_posts)

Collects tags from all posts and renders C<site/tags/index.html> and
C<site/tags/E<lt>slugE<gt>/index.html> for each tag.

=cut

sub gen_tags {
    my ($tt, $config, $all_posts) = @_;
    my $announces = load_announce($top_dir, $config);
    my $tags = collect_tags(@$all_posts);
    gen_tag_pages($tt, $tags, $site_folder, $config, $announces);
}

=head2 gen_sitemap($config, $all_posts)

Writes C<site/sitemap.xml> covering the homepage, archive posts, announcements,
and static pages.  Uses C<lastmod> from post dates where available.

=cut

sub gen_sitemap {
    my ($config, $all_posts) = @_;
    my $base_url = $config->{site_url} // 'https://www.linux.org.hk';
    $base_url =~ s{/$}{};  # strip trailing slash

    my @urls;

    # Static priority pages
    push @urls, { loc => "$base_url/",          priority => '1.0', changefreq => 'daily'   };
    push @urls, { loc => "$base_url/archive/",  priority => '0.8', changefreq => 'daily'   };
    push @urls, { loc => "$base_url/announce/", priority => '0.8', changefreq => 'weekly'  };

    # Archive posts (newest-first already)
    for my $post (@$all_posts) {
        my $lastmod = '';
        if ($post->{date} && $post->{date} =~ /^(\d{4})(\d{2})(\d{2})/) {
            $lastmod = "$1-$2-$3";
        }
        push @urls, {
            loc        => "$base_url$post->{url}",
            priority   => '0.6',
            changefreq => 'never',
            lastmod    => $lastmod,
        };
    }

    # Announcements
    opendir(my $dh, $top_dir) or die $!;
    my @ann_files = sort grep { /\.txt$/ } readdir($dh);
    closedir($dh);
    for my $file (@ann_files) {
        my $post = load_data("$top_dir/$file");
        my $lastmod = '';
        if ($post->{date} && $post->{date} =~ /^(\d{4})(\d{2})(\d{2})/) {
            $lastmod = "$1-$2-$3";
        }
        push @urls, {
            loc        => "$base_url/announce/$post->{slug}.html",
            priority   => '0.5',
            changefreq => 'never',
            lastmod    => $lastmod,
        };
    }

    # Static pages
    opendir(my $dh2, $data_dir) or die $!;
    my @pages = sort grep { /\.txt$/ } readdir($dh2);
    closedir($dh2);
    for my $file (@pages) {
        (my $html = $file) =~ s/\.txt$/.html/;
        push @urls, { loc => "$base_url/$html", priority => '0.4', changefreq => 'monthly' };
    }

    # Write sitemap.xml
    my $out = "$site_folder/sitemap.xml";
    open(my $fh, '>:encoding(UTF-8)', $out) or die "Cannot write $out: $!";
    print $fh qq{<?xml version="1.0" encoding="UTF-8"?>\n};
    print $fh qq{<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n};
    for my $u (@urls) {
        print $fh "  <url>\n";
        print $fh "    <loc>$u->{loc}</loc>\n";
        print $fh "    <lastmod>$u->{lastmod}</lastmod>\n" if $u->{lastmod};
        print $fh "    <changefreq>$u->{changefreq}</changefreq>\n";
        print $fh "    <priority>$u->{priority}</priority>\n";
        print $fh "  </url>\n";
    }
    print $fh "</urlset>\n";
    close $fh;
    print "GEN sitemap.xml (" . scalar(@urls) . " URLs)\n";
}

main();
