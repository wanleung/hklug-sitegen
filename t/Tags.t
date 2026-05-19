#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'lib';

use_ok('Sitegen::Tags', qw(collect_tags tag_slug));

# Test 1: tag_slug lowercases and replaces spaces
is(tag_slug('Open Source'), 'open-source', 'spaces become hyphens');
is(tag_slug('Linux'),       'linux',       'already lowercase unchanged');
is(tag_slug('AI & ML'),    'ai-&-ml',     'non-space chars preserved');

# Test 2: collect_tags builds tag->posts map
my @posts = (
    { title => 'Post A', tags => ['linux', 'event'] },
    { title => 'Post B', tags => ['linux'] },
    { title => 'Post C', tags => ['event', 'open-source'] },
    { title => 'Post D', tags => [] },
);
my $tags = collect_tags(@posts);
is(ref($tags), 'HASH', 'collect_tags returns hashref');
is(scalar @{$tags->{linux}}, 2, 'linux has 2 posts');
is(scalar @{$tags->{event}}, 2, 'event has 2 posts');
is(scalar @{$tags->{'open-source'}}, 1, 'open-source has 1 post');
ok(!exists $tags->{''}, 'empty tags not included');

# Test: undef tag and missing tags key handled gracefully
my @posts_with_undef = (
    { title => 'Post X', tags => [undef, 'linux'] },
    { title => 'Post Y' },
);
my $tags2 = collect_tags(@posts_with_undef);
ok(!exists $tags2->{''}, 'undef tag skipped');
is(scalar @{$tags2->{linux}}, 1, 'valid tag alongside undef still collected');

done_testing();
