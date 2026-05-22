#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Test::More;
use lib 'lib';

# Run sitegen to produce site/ output
# We test against the actual generated files in site/

plan tests => 8;

my $privacy_html = 'site/privacy.html';

SKIP: {
    unless (-f $privacy_html) {
        BAIL_OUT("site/privacy.html missing — run perl bin/sitegen.pl first")
            if $ENV{CI} || $ENV{GITHUB_ACTIONS};
        skip 'site/privacy.html not generated yet — run perl bin/sitegen.pl first', 8;
    }

    open(my $fh, '<:encoding(UTF-8)', $privacy_html) or die "Cannot open $privacy_html: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    ok($content =~ /Privacy Policy/, 'privacy.html contains English title');
    ok($content =~ /私隱政策/, 'privacy.html contains Chinese title');
    ok($content =~ /Hong Kong Linux User Group/, 'privacy.html mentions HKLUG');
    ok($content =~ /do.*not.*collect.*personal data/is || $content =~ /不收集.*個人資料|不會.*收集.*個人資料/,
        'privacy.html states no personal data collected');
    ok($content =~ /info\@linux\.org\.hk/, 'privacy.html contains contact email');
    ok($content =~ /facebook\.com\/privacy/, 'privacy.html links to Meta privacy policy');
    ok($content =~ /2026-05-23/, 'privacy.html contains effective date');

    # Check footer link appears on index.html too
    open(my $idx, '<:encoding(UTF-8)', 'site/index.html') or die "Cannot open site/index.html: $!";
    my $index = do { local $/; <$idx> };
    close $idx;
    ok($index =~ /\/privacy\.html/, 'index.html footer contains privacy policy link');
}
