package Sitegen::Cache;

use strict;
use warnings;
use Exporter 'import';
use Digest::SHA qw(sha256_hex);
use JSON::PP;

our @EXPORT_OK = qw(load_cache save_cache is_fresh update_cache);

sub load_cache {
    my ($cache_file) = @_;
    return {} unless -f $cache_file;
    open(my $fh, '<', $cache_file) or do {
        warn "Cannot read cache file $cache_file: $!\n";
        return {};
    };
    my $json = do { local $/; <$fh> };
    close $fh;
    my $data = eval { decode_json($json) };
    if ($@) {
        warn "Corrupt cache file, starting fresh: $@\n";
        return {};
    }
    return $data;
}

sub save_cache {
    my ($cache_file, $cache) = @_;
    open(my $fh, '>', $cache_file) or die "Cannot write cache $cache_file: $!";
    print $fh JSON::PP->new->pretty->encode($cache);
    close $fh;
}

sub _file_sha256 {
    my ($file) = @_;
    open(my $fh, '<', $file) or die "Cannot read $file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    return sha256_hex($content);
}

sub _basename { (split m{/}, $_[0])[-1] }

sub is_fresh {
    my ($cache, $src_file, $out_file) = @_;
    return 0 unless -f $out_file;
    my $key = _basename($src_file);
    return 0 unless exists $cache->{$key};
    return $cache->{$key} eq _file_sha256($src_file) ? 1 : 0;
}

sub update_cache {
    my ($cache, $src_file) = @_;
    $cache->{_basename($src_file)} = _file_sha256($src_file);
}

=head1 NAME

Sitegen::Cache - SHA-256 incremental cache for sitegen

=head1 SYNOPSIS

  use Sitegen::Cache qw(load_cache save_cache is_fresh update_cache);

  my $cache = load_cache('data/.sitegen-cache.json');
  unless (is_fresh($cache, $src_file, $out_file)) {
      # regenerate $out_file ...
      update_cache($cache, $src_file);
  }
  save_cache('data/.sitegen-cache.json', $cache);

=head1 DESCRIPTION

Manages a JSON file mapping source .txt filenames to their SHA-256 hashes.
C<is_fresh()> returns true only when the hash matches AND the output file exists.
C<update_cache()> stores the current hash for a source file.

=cut

1;
