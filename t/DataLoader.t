#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 10;
use File::Temp qw(tempdir);
use lib 'lib';

use_ok('Sitegen::DataLoader', qw(load_data load_announce));

my $tmpdir = tempdir(CLEANUP => 1);

# Helper: write a temp .txt file
sub write_txt {
    my ($dir, $name, $content) = @_;
    open(my $fh, '>', "$dir/$name") or die $!;
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

# Test 4: load_announce returns most recent file
my $topdir = "$tmpdir/top";
mkdir $topdir;
write_txt($topdir, '001.txt', "Date: 2024-01-01\nAuthor: A\nTitle: Old\nContent:\nOld.");
write_txt($topdir, '002.txt', "Date: 2024-02-01\nAuthor: B\nTitle: New\nContent:\nNew.");
my $announce = load_announce($topdir);
is($announce->{title}, 'New', 'load_announce returns most recent file');

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
