#!/bin/bash

# Copyright 2016  University of Bologna, Italy (Author: Chun Tian)

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

if [ $# -ne 1 ]; then
   echo "Argument should be the APASCI directory, see ../run.sh for example."
   exit 1;
fi

dir=`pwd`/data/local/data
mkdir -p $dir
local=`pwd`/local
utils=`pwd`/utils
conf=`pwd`/conf

. path.sh # Needed for KALDI_ROOT
export PATH=$PATH:$KALDI_ROOT/tools/irstlm/bin
sph2pipe=$KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe
if [ ! -x $sph2pipe ]; then
   echo "Could not find (or execute) the sph2pipe program at $sph2pipe";
   exit 1;
fi

[ -f $conf/train_spk.list ] || error_exit "$PROG: train-set speaker list not found.";
[ -f $conf/dev_spk.list ] || error_exit "$PROG: dev-set (part of train-set) speaker list not found.";
[ -f $conf/test_spk.list ] || error_exit "$PROG: test-set speaker list not found.";

# First check if the corpus directories exist
if [ ! -d "$*/apasci/si" ]; then
  echo "$0: Spot check of command line argument failed"
  echo "Command line argument must be absolute pathname to APASCI directory"
  echo "with names like /export/corpora5/APASCI/1.0"
  exit 1;
fi

tmpdir=$(mktemp -d /tmp/kaldi.XXXX);
trap 'rm -rf "$tmpdir"' EXIT

cat $conf/train_spk.list > $tmpdir/train_spk
cat $conf/dev_spk.list > $tmpdir/dev_spk
cat $conf/test_spk.list > $tmpdir/test_spk

cd $dir
for x in train dev test; do
  # First, find the list of audio files (use only si utterances).
  find $*/apasci/si -not \( -iname 'ca*' \) -iname '*.wav' \
    | grep -f $tmpdir/${x}_spk > ${x}_sph.flist

  sed -e 's:.*/\([mf]\).*/\(.*\)/\(.*\).wav$:\1\2_\3:' ${x}_sph.flist \
    > $tmpdir/${x}_sph.uttids
  paste $tmpdir/${x}_sph.uttids ${x}_sph.flist \
    | sort -k1,1 > ${x}_sph.scp

  cat ${x}_sph.scp | awk '{print $1}' > ${x}.uttids

  # Now, Convert the transcripts into our format (no normalization yet)
  # Get the transcripts: each line of the output contains an utterance
  # ID followed by the transcript.
  find $*/apasci/si -not \( -iname 'ca*' \) -iname '*.phn' \
    | grep -f $tmpdir/${x}_spk > $tmpdir/${x}_phn.flist
  sed -e 's:.*/\([mf]\).*/\(.*\)/\(.*\).phn$:\1\2_\3:' $tmpdir/${x}_phn.flist \
    > $tmpdir/${x}_phn.uttids
  while read line; do
    [ -f $line ] || error_exit "Cannot find transcription file '$line'";
    cut -f3 -d' ' "$line" | tr '\n' ' ' | sed -e 's: *$:\n:'
  done < $tmpdir/${x}_phn.flist > $tmpdir/${x}_phn.trans
  paste $tmpdir/${x}_phn.uttids $tmpdir/${x}_phn.trans \
    | sort -k1,1 > ${x}.trans_pre

  # Do normalization steps.
  $local/apasci_norm_trans.pl -i ${x}.trans_pre -m $conf/phones.map | sort > ${x}.trans || exit 1;

  # Generate texts for training
  find $*/apasci/si -not \( -iname 'ca*' \) -iname '*.txt' \
    | grep -f $tmpdir/${x}_spk > $tmpdir/${x}_txt.flist
  sed -e 's:.*/\([mf]\).*/\(.*\)/\(.*\).txt$:\1\2_\3:' $tmpdir/${x}_txt.flist \
    > $tmpdir/${x}_txt.uttids
  while read line; do
    [ -f $line ] || error_exit "Cannot find transcription file '$line'";
    cut -f3- -d' ' "$line"
  done < $tmpdir/${x}_txt.flist > $tmpdir/${x}_txt.trans
  paste $tmpdir/${x}_txt.uttids $tmpdir/${x}_txt.trans \
      | sort -k1,1 > ${x}.text

  # Create wav.scp
  awk '{printf("%s '$sph2pipe' -f wav %s |\n", $1, $2);}' < ${x}_sph.scp > ${x}_wav.scp

  # Make the utt2spk and spk2utt files.
  cut -f1 -d'_'  $x.uttids | paste -d' ' $x.uttids - > $x.utt2spk 
  cat $x.utt2spk | $utils/utt2spk_to_spk2utt.pl > $x.spk2utt || exit 1;

  # Prepare gender mapping
  cat $x.spk2utt | awk '{print $1}' | perl -ane 'chop; m:^.:; $g = lc($&); print "$_ $g\n";' > $x.spk2gender

  # Prepare STM file for sclite:
  wav-to-duration scp:${x}_wav.scp ark,t:${x}_dur.ark 2>&1 | grep -v 'nonzero return status' || exit 1
  gawk -v dur=${x}_dur.ark \
  'BEGIN{
     while(getline < dur) { durH[$1]=$2; }
     print ";; LABEL \"O\" \"Overall\" \"Overall\"";
     print ";; LABEL \"F\" \"Female\" \"Female speakers\"";
     print ";; LABEL \"M\" \"Male\" \"Male speakers\"";
   }
   { wav=$1; spk=gensub(/_.*/,"",1,wav); $1=""; ref=$0;
     gender=(substr(spk,0,1) == "f" ? "F" : "M");
     printf("%s 1 %s 0.0 %f <O,%s> %s\n", wav, spk, durH[wav], gender, ref);
   }
  ' ${x}.text >${x}.stm || exit 1

  # Create dummy GLM file for sclite:
  echo ';; empty.glm
  [FAKE]     =>  %HESITATION     / [ ] __ [ ] ;; hesitation token
  ' > ${x}.glm
done

echo "Data preparation succeeded"
