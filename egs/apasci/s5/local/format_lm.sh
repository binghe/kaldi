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

srcdir=data/local/data
lmdir=data/local/lm

[ -f path.sh ] && . path.sh || exit 1;

echo "Preparing train and test data"

for x in train dev test; do
  mkdir -p data/$x
  cp $srcdir/${x}_wav.scp data/$x/wav.scp || exit 1;
  cp $srcdir/$x.text data/$x/text || exit 1;
  cp $srcdir/$x.spk2utt data/$x/spk2utt || exit 1;
  cp $srcdir/$x.utt2spk data/$x/utt2spk || exit 1;
  utils/filter_scp.pl data/$x/spk2utt $srcdir/$x.spk2gender > data/$x/spk2gender || exit 1;
  cp $srcdir/${x}.stm data/$x/stm
  cp $srcdir/${x}.glm data/$x/glm
  utils/validate_data_dir.sh --no-feats data/$x || exit 1
done

# Next, for each type of language model, create the corresponding FST
# and the corresponding lang_test_* directory.

echo Preparing language model for test

# First check if the corpus directories exist
if [ ! -f $* ]; then
  echo "$0: Spot check of command line argument failed"
  echo "Command line argument must be absolute pathname to CORIS LM"
  echo "with names like /export/corpora5/CORIS4word2vecNOMWE_APO.arpa.lm.bz2"
  exit 1;
fi

arpa_lm=$*

for lm_suffix in bg; do
  test=data/lang_test_${lm_suffix}
  mkdir -p $test
  cp -r data/lang/* $test

  if [ -f $test/G.fst ]; then
      echo "$0: not regenerating data/lang/G.fst as it already exists"
  else
      echo "$0: generating G.fst using ${arpa_lm} ..."
      arpa2fst --disambig-symbol=#0 --read-symbol-table=$test/words.txt \
	       $lmdir/arpa.lm $test/G.fst
      echo "$0: Checking how stochastic G is (the first of these numbers should be small):"
      fstisstochastic $test/G.fst || true
      utils/validate_lang.pl --skip-determinization-check $test || exit 1
  fi
done

cp -rT data/lang data/lang_rescore
cp data/lang_test_bg/G.fst data/lang/

echo "Succeeded in formatting data."

exit 0
