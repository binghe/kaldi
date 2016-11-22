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

## Online decoding using trained nnet3 model

[ -f path.sh ] && . path.sh

# First check if the corpus directories exist
if [ ! -f "$1" ]; then
  echo "$0: Spot check of command line argument failed"
  echo "Command line argument must be absolute pathname to a WAV audio"
  echo "with names like test.wav"
  exit 1;
fi

model=exp/nnet3/tdnn_sp
graph=exp/tri3/graph

wav=$1

${KALDI_ROOT}/src/online2bin/online2-wav-nnet3-latgen-faster --do-endpointing=false \
    --online=false \
    --config=conf/online_decoding.conf \
    --max-active=7000 --beam=15.0 --lattice-beam=6.0 \
    --acoustic-scale=0.1 --word-symbol-table=$graph/words.txt \
    $model/final.mdl $graph/HCLG.fst \
    "ark:echo utterance-id1 utterance-id1|" "scp:echo utterance-id1 ${wav}|" \
    ark:/dev/null
