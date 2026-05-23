#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 31;
use File::Temp qw(tempdir);
use lib 'lib';

use_ok('Sitegen::DataLoader', qw(load_data load_announce));

my $tmpdir = tempdir(CLEANUP => 1);

# Helper: write a temp .txt file
sub write_txt {
    my ($dir, $name, $content) = @_;
    open(my $fh, '>:encoding(UTF-8)', "$dir/$name") or die $!;
    print $fh $content;
    close $fh;
    return "$dir/$name";
}

# Test 1: basic fields parsed
my $f = write_txt($tmpdir, 'test1.txt', <<'END');
Date: 2024-01-15 18:00
Author: Wan Leung Wong
Title: Test Post
Content:
Hello **world**.
END
my $post = load_data($f);
is($post->{date},   '2024-01-15 18:00', 'date parsed');
is($post->{author}, 'Wan Leung Wong',   'author parsed');
is($post->{title},  'Test Post',        'title parsed');
like($post->{content}, qr/<strong>world<\/strong>|<b>world<\/b>/, 'content markdown rendered');

# Test 2: no Tags: line → empty arrayref
is(ref($post->{tags}), 'ARRAY', 'tags is arrayref');
is(scalar @{$post->{tags}}, 0, 'no tags = empty array');

# Test 3: Tags: line parsed and lowercased
my $f2 = write_txt($tmpdir, 'test2.txt', <<'END');
Date: 2024-02-01 10:00
Author: Bot
Title: Tagged Post
Tags: Linux, Open-Source, EVENT
Content:
Body.
END
my $post2 = load_data($f2);
is_deeply($post2->{tags}, ['linux', 'open-source', 'event'], 'tags lowercased and trimmed');

# Test 4: load_announce returns arrayref with most recent HKLUG file
my $topdir = "$tmpdir/top";
mkdir $topdir;
write_txt($topdir, '001.txt', "Date: 2024-01-01\nAuthor: A\nTitle: Old\nContent:\nOld.");
write_txt($topdir, '002.txt', "Date: 2024-02-01\nAuthor: B\nTitle: New\nContent:\nNew.");
my $announces = load_announce($topdir);
is(ref($announces), 'ARRAY', 'load_announce returns arrayref');
is($announces->[0]{title}, 'New', 'load_announce returns most recent HKLUG file');

# Test 4b: with more than 3 files, returns exactly 3 most recent
write_txt($topdir, 'oshk-latest.txt',   "Date: 2026-01-01\nAuthor: OSHK\nTitle: OSHK Post\nContent:\nBody.");
write_txt($topdir, 'hkoscon-latest.txt',"Date: 2026-01-01\nAuthor: HKOSCon\nTitle: HKOSCon Post\nContent:\nBody.");
my $announces2 = load_announce($topdir);
is(scalar @$announces2, 3, 'load_announce returns max 3 items from 4 files');
is($announces2->[0]{title}, 'OSHK Post',    'most recent file first (oshk-latest sorts last)');
is($announces2->[1]{title}, 'HKOSCon Post', 'second most recent');
is($announces2->[2]{title}, 'New',          'third most recent (002.txt)');

# Test 4c: fewer than 3 files returns all files
my $topdir2 = "$tmpdir/top2"; mkdir $topdir2;
write_txt($topdir2, 'aaa.txt', "Date: 2026-01-01\nAuthor: A\nTitle: First\nContent:\nBody.");
write_txt($topdir2, 'bbb.txt', "Date: 2026-02-01\nAuthor: B\nTitle: Second\nContent:\nBody.");
my $announces3 = load_announce($topdir2);
is(scalar @$announces3, 2, 'fewer than 3 files returns all files');
is($announces3->[0]{title}, 'Second', 'most recent first when only 2 files');

# Test 4d: single file returns 1 item
my $topdir3 = "$tmpdir/top3"; mkdir $topdir3;
write_txt($topdir3, 'single.txt', "Date: 2026-03-01\nAuthor: A\nTitle: Lone Post\nContent:\nBody.");
my $announces4 = load_announce($topdir3);
is(scalar @$announces4, 1, 'single file returns 1 item');
is($announces4->[0]{title}, 'Lone Post', 'title correct for single file');

# Test 5: comment lines skipped
my $f3 = write_txt($tmpdir, 'test3.txt', <<'END');
// this is a comment
Date: 2024-03-01 09:00
Author: Bot
Title: With Comment
Content:
Body.
END
my $post3 = load_data($f3);
is($post3->{date}, '2024-03-01 09:00', 'comment lines skipped');

# Test 6: // lines in content body are preserved
my $f4 = write_txt($tmpdir, 'test4.txt', <<'END');
Date: 2024-04-01
Author: Bot
Title: Code Post
Content:
Line one.
// this should NOT be stripped from content
Line two.
END
my $post4 = load_data($f4);
like($post4->{content}, qr/this should NOT be stripped/, '// lines in content body are preserved');

# Test 7: Tags: with no value gives empty array
my $f5 = write_txt($tmpdir, 'test5.txt', "Date: 2024-05-01\nAuthor: A\nTitle: T\nTags:\nContent:\nBody.\n");
my $post5 = load_data($f5);
is(scalar @{$post5->{tags}}, 0, 'Tags: with no value gives empty array');

# Test 8: load_announce returns empty arrayref on empty dir (no die)
my $emptydir = "$tmpdir/empty"; mkdir $emptydir;
my $empty_ann = load_announce($emptydir);
is(ref($empty_ann), 'ARRAY', 'load_announce returns arrayref on empty dir');
is(scalar @$empty_ann, 0, 'load_announce returns empty array when no files found');

# Test 9: unsafe tags (path traversal) are skipped with a warning
my $f6 = write_txt($tmpdir, 'test6.txt', "Date: 2024-06-01\nAuthor: A\nTitle: T\nTags: linux, ../evil, good-tag, /etc/passwd\nContent:\nBody.\n");
my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @_ };
my $post6 = load_data($f6);
is_deeply($post6->{tags}, ['linux', 'good-tag'], 'unsafe tags skipped');
is(scalar @warnings, 2, 'two warnings emitted for two unsafe tags');

# Test 10: slug is set from filename
my $slugfile = write_txt($tmpdir, '20260101-slug-test.txt', "Date: 2026-01-01\nAuthor: A\nTitle: Slug\nContent:\nBody.\n");
my $slugpost = load_data($slugfile);
is($slugpost->{slug}, '20260101-slug-test', 'slug is basename without .txt');

# Test 11: excerpt strips HTML tags and truncates to 180 chars
my $longfile = write_txt($tmpdir, 'long.txt', "Date: 2026-01-01\nAuthor: A\nTitle: Long\nContent:\n" . ("word " x 60) . "\n");
my $longpost = load_data($longfile);
ok(defined $longpost->{excerpt}, 'excerpt is set');
ok(length($longpost->{excerpt}) <= 183, 'excerpt is max 180 chars plus ...');  # 180 + "..."
like($longpost->{excerpt}, qr/\.\.\.$/, 'long excerpt ends with ...');

# Test 12: short content excerpt has no trailing ellipsis
my $shortfile = write_txt($tmpdir, 'short.txt', "Date: 2026-01-01\nAuthor: A\nTitle: Short\nContent:\nShort content.\n");
my $shortpost = load_data($shortfile);
unlike($shortpost->{excerpt}, qr/\.\.\.$/, 'short excerpt has no ...');
is($shortpost->{excerpt}, 'Short content.', 'short excerpt matches plain text');

