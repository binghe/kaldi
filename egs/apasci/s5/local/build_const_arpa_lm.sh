#!/bin/bash

# Copyright 2014  Guoguo Chen
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

# This script reads in an Arpa format language model, and converts it into the
# ConstArpaLm format language model.

[ -f path.sh ] && . path.sh

. utils/parse_options.sh

if [ $# != 3 ]; then
  echo "Usage: "
  echo "  $0 [options] <arpa-lm-path> <old-lang-dir> <new-lang-dir>"
  echo "e.g.:"
  echo "  $0 data/local/lm/3-gram.full.arpa.gz data/lang/ data/lang_test_tgmed"
  echo "Options"
  exit 1;
fi

export LC_ALL=C

arpa_lm=$1
old_lang=$2
new_lang=$3

mkdir -p $new_lang

mkdir -p $new_lang
cp -r $old_lang/* $new_lang

unk=`cat $new_lang/oov.int`
bos=`grep "<s>" $new_lang/words.txt | awk '{print $2}'`
eos=`grep "</s>" $new_lang/words.txt | awk '{print $2}'`

if [[ -z $bos || -z $eos ]]; then
  echo "$0: <s> and </s> symbols are not in $new_lang/words.txt"
  exit 1
fi

arpa-to-const-arpa --bos-symbol=$bos \
  --eos-symbol=$eos --unk-symbol=$unk \
  "bunzip2 -c $arpa_lm | local/prune_lm.pl | utils/map_arpa_lm.pl $new_lang/words.txt |"  $new_lang/G.carpa  || exit 1;

exit 0;
