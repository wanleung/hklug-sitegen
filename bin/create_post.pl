#!/usr/bin/perl

use strict;
use warnings;
use File::Copy;
use FindBin qw($Bin);
use lib "$Bin/../lib";


our $data_path = "$Bin/../data/news";
our $template = "$Bin/../TEMPLATE.txt";

sub main {
  my $datefile = `date '+%Y%m%d-%H%M%S'`;
  my $date = `date '+%Y-%m-%d %H:%M'`;
  chomp $date;
  chomp $datefile;
  #copy("$template", "$data_path/$datefile.txt");
  #system('/usr/bin/perl', '-p', '-i', '-e', '"s/\[%DATE\]/'.$date.'/g"', "$data_path/$datefile.txt");
  open FILEIN, "<$template";
  open FILEOUT, ">$data_path/$datefile.txt";
  while (<FILEIN>) {
      my $line = $_;
      $line =~ s/\[%DATE\]/$date/;
      print $line;
      print FILEOUT $line;
  }
  close FILEIN;
  close FILEOUT;
}

main();
