#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'lib';

use_ok('Sitegen::SEO', qw(seo_meta));

my $config = {
    site_url         => 'https://hklug.org',
    site_name        => 'HKLUG',
    site_description => 'Linux users in HK.',
};

# Test 1: og_url constructed correctly
my $post = { title => 'My Post', content => '<p>Hello world.</p>' };
my $seo  = seo_meta($post, $config, '/archive/20240101-120000.html');
is($seo->{og_url}, 'https://hklug.org/archive/20240101-120000.html', 'og_url correct');

# Test 2: og_title from post title
is($seo->{og_title}, 'My Post', 'og_title from post title');

# Test 3: HTML stripped from description
is($seo->{description}, 'Hello world.', 'HTML stripped from description');

# Test 4: description same as og_description
is($seo->{description}, $seo->{og_description}, 'description == og_description');

# Test 5: long content truncated to 160 chars
my $long = 'A' x 200;
my $seo2 = seo_meta({ title => 'T', content => $long }, $config, '/');
is(length($seo2->{description}), 160, 'description truncated to 160 chars');

# Test 6: empty content falls back to site_description
my $seo3 = seo_meta({ title => 'T', content => '' }, $config, '/');
is($seo3->{description}, 'Linux users in HK.', 'empty content uses site_description');

# Test 7: trailing slash removed from site_url
my $cfg2 = { %$config, site_url => 'https://hklug.org/' };
my $seo4 = seo_meta($post, $cfg2, '/archive/x.html');
is($seo4->{og_url}, 'https://hklug.org/archive/x.html', 'trailing slash stripped from site_url');

done_testing();
