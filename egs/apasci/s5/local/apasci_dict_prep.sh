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

# Call this script from one level above, e.g. from the s5/ directory.  It puts
# its output in data/local/.

# The parts of the output of this that will be needed are
# [in data/local/dict/ ]
# lexicon.txt
# extra_questions.txt
# nonsilence_phones.txt
# optional_silence.txt
# silence_phones.txt

# run this from ../
srcdir=data/local/data
dir=data/local/dict
lmdir=data/local/lm
tmpdir=data/local/lm_tmp

mkdir -p $dir $lmdir $tmpdir

[ -f path.sh ] && . ./path.sh

if [ ! -f $* ]; then
  echo "$0: Spot check of command line argument failed"
  echo "Command line argument must be absolute pathname to CORIS LM"
  echo "with names like /export/corpora5/CORIS4word2vecNOMWE_APO.arpa.lm.bz2"
  exit 1;
fi

arpa_lm=$*

if ! command -v g2p >/dev/null 2>&1 ; then
  echo "$0: Error: the G2P (CMU Flite) tool is not available or compiled" >&2
  echo "$0: Error: We used to install it by default, but." >&2
  echo "$0: Error: this is no longer the case." >&2
  echo "$0: Error: To install it, go to $KALDI_ROOT/tools" >&2
  echo "$0: Error: and run extras/install_flite-italian.sh" >&2
  exit 1
fi

if ! command -v ngram >/dev/null 2>&1 ; then
  echo "$0: Error: the SRILM tool is not available or compiled" >&2
  echo "$0: Error: We used to install it by default, but." >&2
  echo "$0: Error: this is no longer the case." >&2
  echo "$0: Error: To install it, go to $KALDI_ROOT/tools" >&2
  echo "$0: Error: and run install_srilm.sh" >&2
  exit 1
fi

#(1) Dictionary preparation:

# Make phones symbol-table (adding in silence and verbal and non-verbal noises at this point).
# We are adding suffixes _B, _E, _S for beginning, ending, and singleton phones.

# silence phones, one per line.
echo "SIL" > $dir/silence_phones.txt
echo "SIL" > $dir/optional_silence.txt

# nonsilence phones; on each line is a list of phones that correspond
# really to the same base phone.

cut -d' ' -f2- $srcdir/train.trans | tr ' ' '\n' | sort -u > $dir/phones.txt

grep -v -F -f $dir/silence_phones.txt $dir/phones.txt > $dir/nonsilence_phones.txt 

# A few extra questions that will be added to those obtained by automatically clustering
# the "real" phones.  These ask about stress; there's also one for silence.
cat $dir/silence_phones.txt | awk '{printf("%s ", $1);} END{printf "\n";}' > $dir/extra_questions.txt || exit 1;
cat $dir/nonsilence_phones.txt | perl -e 'while(<>){ foreach $p (split(" ", $_)) {
  $p =~ m:^([^\d]+)(\d*)$: || die "Bad phone $_"; $q{$2} .= "$p "; } } foreach $l (values %q) {print "$l\n";}' \
 >> $dir/extra_questions.txt || exit 1;

# Make the initial lexicon
echo "<SIL> SIL" > $dir/lexicon.txt
# Append phoneme-based lexicon (just an identity mapping)
paste $dir/phones.txt $dir/phones.txt >> $dir/lexicon.txt || exit 1;

## Now preparing the real lexicon from CORIS LM

# Step 1: convert Latin-1 letters to ASCII letters for Italian
# NOTE: the arpa.lm file will be used again in `format_lm.sh'
if [ -f $lmdir/arpa.lm ]; then
    echo "$0: not regenerating $lmdir/arpa.lm as it already exists"
else
    echo "$0: generating $lmdir/arpa.lm using ${arpa_lm} ..."
    bunzip2 -c $arpa_lm | local/prune_lm.pl > $lmdir/arpa.lm
fi

# Step 2: use SRILM tools to extract the vocabulary from N-gram
if [ -f $lmdir/vocab.txt ]; then
    echo "$0: not regenerating $lmdir/vocab.txt as it already exists"
else
    echo "$0: extracting vocabulary from LM ..."
    ngram -lm $lmdir/arpa.lm -unk -write-vocab $tmpdir/vocab.txt
    # clean up the vocab, left only regular Italian words
    grep "^[a-z]*[a-z']$" $tmpdir/vocab.txt | sort | uniq > $lmdir/vocab.txt
fi

# Step 3: generate lexicon using CMU flite 1.2 (with Italian support)
echo "$0: generating lexicon from LM vocabulary ..."
while read line; do
    # for echo g2p output, we removed accents and combined all double-consonants to
    # make it SAMPA compatible according to APASCI's sampa.doc
    echo "$line " `g2p "$line"` | sed -e "s/[1#]//g;s/\([fvsSptkbdgmnJlrL]\) \1 /\1\1 /g" \
    >> $dir/lexicon.txt
done < $lmdir/vocab.txt

# Check that the dict dir is okay!
utils/validate_dict_dir.pl $dir || exit 1

rm -rf $tmpdir

echo "Dictionary preparation succeeded"
