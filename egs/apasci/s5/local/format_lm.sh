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
tmpdir=data/local/lm_tmp

mkdir -p $lmdir $tmpdir

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

lm_suffix=bg
test=data/lang_test_${lm_suffix}

mkdir -p $test
cp -r data/lang/* $test

# G1.fst is a bigram based on phonemes
if [ -f $test/G1.fst ]; then
    echo "$0: not regenerating data/lang/G1.fst as it already exists"
else
    echo "$0: generating G1.fst using train data ..."

    cut -d' ' -f2- $srcdir/train.trans | sed -e 's:^:<s> :' -e 's:$: </s>:' \
	> $srcdir/lm_train.trans

    build-lm.sh -i $srcdir/lm_train.trans -n 2 -o $tmpdir/lm_phone_${lm_suffix}.ilm.gz
    compile-lm $tmpdir/lm_phone_${lm_suffix}.ilm.gz -t=yes /dev/stdout | \
	grep -v unk | gzip -c > $lmdir/lm_phone_${lm_suffix}.arpa.gz

    gunzip -c $lmdir/lm_phone_${lm_suffix}.arpa.gz | \
    arpa2fst --disambig-symbol=#0 \
             --read-symbol-table=$test/words.txt - $test/G1.fst
    echo "$0: Checking how stochastic G1 is (the first of these numbers should be small):"
    fstisstochastic $test/G1.fst || true
fi

# G2.fst is a bigram based on words
if [ -f $test/G2.fst ]; then
    echo "$0: not regenerating data/lang/G2.fst as it already exists"
else
    echo "$0: generating G2.fst using ${arpa_lm} ..."
    arpa2fst --disambig-symbol=#0 --read-symbol-table=$test/words.txt \
	     $lmdir/arpa.lm $test/G2.fst
    # remove too big temp LM files
    # rm $lmdir/arpa.lm
    echo "$0: Checking how stochastic G2 is (the first of these numbers should be small):"
    fstisstochastic $test/G2.fst || true
fi

if [ -f $test/G.fst ]; then
    echo "$0: not regenerating data/lang/G.fst as it already exists"
else
    echo "$0: generating G.fst using G1.fst and G2.fst ..."
    fstunion $test/G1.fst $test/G2.fst | fstarcsort --sort_type=ilabel > G.fst
    echo "$0: Checking how stochastic G is (the first of these numbers should be small):"
    fstisstochastic $test/G.fst || true
fi

utils/validate_lang.pl --skip-determinization-check $test || exit 1

cp -rT data/lang data/lang_rescore
cp data/lang_test_bg/G.fst data/lang/

rm -rf $tmpdir

echo "Succeeded in formatting data."

exit 0
