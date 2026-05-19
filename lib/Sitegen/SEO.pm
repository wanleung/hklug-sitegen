package Sitegen::SEO;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(seo_meta);

sub seo_meta {
    my ($post, $config, $url_path) = @_;

    my $content = $post->{content} // '';
    (my $plain = $content) =~ s/<[^>]+>//g;
    $plain =~ s/\s+/ /g;
    $plain =~ s/^\s+|\s+$//g;

    my $description = length($plain) > 0
        ? substr($plain, 0, 160)
        : ($config->{site_description} // '');

    (my $base = $config->{site_url} // '') =~ s|/$||;

    return {
        description    => $description,
        og_title       => $post->{title} // $config->{site_name} // '',
        og_description => $description,
        og_url         => "$base$url_path",
    };
}

=head1 NAME

Sitegen::SEO - Generate SEO meta hashref for hklug-sitegen pages

=head1 SYNOPSIS

  use Sitegen::SEO qw(seo_meta);

  my $seo = seo_meta($post, $config, '/archive/20240101.html');
  # Returns hashref: description, og_title, og_description, og_url

=head1 DESCRIPTION

Strips HTML from post content, truncates to 160 chars, and assembles
the meta hashref consumed by the [% IF seo %] block in header.html.
Falls back to C<site_description> from config when content is empty.

=cut

1;
