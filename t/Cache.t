#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 9;
use File::Temp qw(tempdir tempfile);
use lib 'lib';

use_ok('Sitegen::Cache', qw(load_cache save_cache is_fresh update_cache));

my $tmpdir = tempdir(CLEANUP => 1);

# Test 1: load_cache on missing file returns empty hashref
my $cache = load_cache("$tmpdir/nonexistent.json");
is(ref($cache), 'HASH', 'missing cache returns hashref');
is(scalar keys %$cache, 0, 'missing cache is empty');

# Test 2: save_cache then load_cache round-trips
my $data = { 'foo.txt' => 'abc123' };
save_cache("$tmpdir/cache.json", $data);
my $loaded = load_cache("$tmpdir/cache.json");
is($loaded->{'foo.txt'}, 'abc123', 'save and load round-trip');

# Test 3: corrupt cache returns empty hashref with warning
open(my $fh, '>', "$tmpdir/bad.json") or die $!;
print $fh "NOT JSON {{{{";
close $fh;
my $bad = load_cache("$tmpdir/bad.json");
is(ref($bad), 'HASH', 'corrupt cache returns hashref');
is(scalar keys %$bad, 0, 'corrupt cache is empty');

# Test 4: update_cache + is_fresh
my $srcfile = "$tmpdir/article.txt";
open($fh, '>', $srcfile) or die $!;
print $fh "Date: 2024-01-01\nContent:\nHello.";
close $fh;

my $outfile = "$tmpdir/article.html";
open($fh, '>', $outfile) or die $!; print $fh "<p>Hello.</p>"; close $fh;

my $c = {};
is(is_fresh($c, $srcfile, $outfile), 0, 'not fresh before update_cache');

update_cache($c, $srcfile);
is(is_fresh($c, $srcfile, $outfile), 1, 'fresh after update_cache');

# Test 5: is_fresh returns 0 when output file missing
unlink $outfile;
is(is_fresh($c, $srcfile, $outfile), 0, 'not fresh when output file missing');
