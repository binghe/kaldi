#!/usr/bin/env perl
use warnings; #sed replacement for -w perl parameter

# Copyright 2012  Arnab Ghoshal
#           2016  University of Bologna, Italy (Author: Chun Tian)

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.


# This script normalizes the APASCI phonetic transcripts that have been 
# extracted in a format where each line contains an utterance ID followed by 
# the transcript, e.g.:
# stga0_di63205	@bg i k s m E ddz o @bg e t a r d o s o gg i JJ o @bgn

my $usage = "Usage: apasci_norm_trans.pl -i transcript -m phone_map > normalized\n
Normalizes phonetic transcriptions for APASCI, by mapping the special marks to sil.\n";

use strict;
use Getopt::Long;
die "$usage" unless(@ARGV >= 1);
my ($in_trans, $phone_map, $num_phones_out);
GetOptions ("i=s" => \$in_trans,          # Input transcription
	    "m=s" => \$phone_map);        # File containing phone mappings

die $usage unless(defined($in_trans) && defined($phone_map));

open(M, "<$phone_map") or die "Cannot open mappings file '$phone_map': $!";
my (%phonemap, %seen_phones);
my $num_seen_phones = 0;
while (<M>) {
  chomp;
  # next if ($_ =~ /^q\s*.*$/); # Ignore glottal stops.
  m:^(\S+)\s+(\S+)$: or die "Bad line: $_";
  my $mapped_from = $1;
  my $mapped_to = $2;
  if (!defined($seen_phones{$mapped_to})) {
    $seen_phones{$mapped_to} = 1;
    $num_seen_phones += 1;
  }
  $phonemap{$mapped_from} = $mapped_to;
}

open(T, "<$in_trans") or die "Cannot open transcription file '$in_trans': $!";
while (<T>) {
  chomp;
  $_ =~ m:^(\S+)\s+(.+): or die "Bad line: $_";
  my $utt_id = $1;
  my $trans = $2;

  # $trans =~ s/q//g;  # Remove glottal stops.
  $trans =~ s/^\s*//; $trans =~ s/\s*$//;  # Normalize spaces

  print $utt_id;
  for my $phone (split(/\s+/, $trans)) {
    if(exists $phonemap{$phone}) { print " $phonemap{$phone}"; }
    if(not exists $phonemap{$phone}) { print " $phone"; }
  }
  print "\n";
}
