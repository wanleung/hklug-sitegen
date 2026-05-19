package Sitegen::Tags;

use strict;
use warnings;
use Exporter 'import';
use File::Path qw(make_path);
use Sitegen::SEO qw(seo_meta);

our @EXPORT_OK = qw(collect_tags tag_slug gen_tag_pages);

sub _tt_process {
    my ($tt, $template, $vars, $outfile) = @_;
    open(my $fh, '>:encoding(UTF-8)', $outfile) or die "Cannot open $outfile: $!";
    $tt->process($template, $vars, $fh) or die $tt->error();
    close $fh or die "Cannot write $outfile: $!";
}

sub tag_slug {
    my ($tag) = @_;
    (my $slug = lc $tag) =~ s/\s+/-/g;
    return $slug;
}

sub collect_tags {
    my (@posts) = @_;
    my %tags;
    for my $post (@posts) {
        for my $tag (@{$post->{tags} // []}) {
            next unless defined $tag && length $tag;
            push @{$tags{$tag}}, $post;
        }
    }
    return \%tags;
}

sub gen_tag_pages {
    my ($tt, $tags, $site_folder, $config, $announces) = @_;
    my $tags_folder = "$site_folder/tags";
    make_path($tags_folder);

    my @tag_list = map {
        { name => $_, slug => tag_slug($_), count => scalar @{$tags->{$_}} }
    } sort keys %$tags;

    _tt_process($tt, 'tag_list.html',
        {
            title     => $config->{site_name} . ' > Tags',
            tag_list  => \@tag_list,
            announces => $announces,
            seo       => seo_meta(
                { title => $config->{site_name} . ' > Tags', content => '' },
                $config, '/tags/'
            ),
        },
        "$tags_folder/index.html"
    );

    for my $tag (keys %$tags) {
        my $slug    = tag_slug($tag);
        my $tag_dir = "$tags_folder/$slug";
        make_path($tag_dir);
        _tt_process($tt, 'tag_page.html',
            {
                title     => $config->{site_name} . " > Tag: $tag",
                tag       => $tag,
                slug      => $slug,
                posts     => $tags->{$tag},
                announces => $announces,
                seo       => seo_meta(
                    { title => $config->{site_name} . " > Tag: $tag", content => '' },
                    $config, "/tags/$slug/"
                ),
            },
            "$tag_dir/index.html"
        );
    }
}

=head1 NAME

Sitegen::Tags - Tag collection and page generation for hklug-sitegen

=head1 SYNOPSIS

  use Sitegen::Tags qw(collect_tags tag_slug gen_tag_pages);

  my $tags = collect_tags(@posts);
  # Returns hashref: { 'linux' => [$post1, $post2], ... }

  my $slug = tag_slug('Open Source');  # returns 'open-source'

  gen_tag_pages($tt, $tags, $site_folder, $config);
  # Creates site/tags/index.html and site/tags/<slug>/index.html

=head1 DESCRIPTION

C<collect_tags()> builds a tag-to-posts mapping from a list of post hashrefs.
Each post must have a C<tags> key containing an arrayref of tag strings.

C<tag_slug()> converts a tag name to a URL-safe slug: lowercased, spaces to hyphens.

C<gen_tag_pages()> uses Template Toolkit to render tag index and per-tag pages.
Requires templates C<tag_list.html> and C<tag_page.html>.

=cut

1;
