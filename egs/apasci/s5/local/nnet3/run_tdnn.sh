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

#    This is the standard "tdnn" system, built in nnet3; this script
# is the version that's meant to run with data-cleanup, that doesn't
# support parallel alignments.

# by default, with cleanup:
# local/nnet3/run_tdnn.sh

# without cleanup:
# local/nnet3/run_tdnn.sh  --train-set train --gmm tri3 --nnet3-affix "" &


set -e -o pipefail -u

# First the options that are passed through to run_ivector_common.sh
# (some of which are also used in this script directly).
stage=0
nj=30
decode_nj=30
min_seg_len=1.55
train_set=train
gmm=tri3
                  # should have alignments for the specified training data.
num_threads_ubm=32
nnet3_affix=  # cleanup affix for exp dirs, e.g. _cleaned
tdnn_affix=  #affix for TDNN directory e.g. "a" or "b", in case we change the configuration.

# Options which are not passed through to run_ivector_common.sh
train_stage=-10
splice_indexes="-2,-1,0,1,2 -1,2 -3,3 -7,2 -3,3 0 0"
remove_egs=true
relu_dim=850
num_epochs=8

. cmd.sh
. path.sh
. utils/parse_options.sh

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

local/nnet3/run_ivector_common.sh --stage $stage \
                                  --nj $nj \
                                  --min-seg-len $min_seg_len \
                                  --train-set $train_set \
                                  --gmm $gmm \
                                  --num-threads-ubm $num_threads_ubm \
                                  --nnet3-affix "$nnet3_affix"



gmm_dir=exp/${gmm}
graph_dir=$gmm_dir/graph
ali_dir=exp/${gmm}_ali_${train_set}_sp_comb
dir=exp/nnet3${nnet3_affix}/tdnn${tdnn_affix}_sp
train_data_dir=data/${train_set}_sp_hires_comb
train_ivector_dir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires_comb

for f in $train_data_dir/feats.scp $train_ivector_dir/ivector_online.scp \
     $graph_dir/HCLG.fst $ali_dir/ali.1.gz $gmm_dir/final.mdl; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

if [ $stage -le 12 ]; then
  # use local/nnet3/train.sh for debug purposes if something goes wrong here.
  steps/nnet3/tdnn/train.sh --stage $train_stage \
    --num-epochs $num_epochs --num-jobs-initial 1 --num-jobs-final 3 \
    --splice-indexes "$splice_indexes" \
    --feat-type raw \
    --online-ivector-dir ${train_ivector_dir} \
    --cmvn-opts "--norm-means=false --norm-vars=false" \
    --initial-effective-lrate 0.0015 --final-effective-lrate 0.00015 \
    --cmd "$decode_cmd" \
    --relu-dim "$relu_dim" \
    --remove-egs "$remove_egs" \
    $train_data_dir data/lang $ali_dir $dir
fi

if [ $stage -le 13 ]; then
  rm -f $dir/.error || true 2>/dev/null
  for dset in test; do
   (
    steps/nnet3/decode.sh --nj $decode_nj --cmd "$decode_cmd"  --num-threads 4 \
	--online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_${dset}_hires \
	${graph_dir} data/${dset}_hires ${dir}/decode_${dset} || exit 1
    steps/lmrescore.sh --cmd "$decode_cmd" data/lang data/lang_rescore \
	data/${dset}_hires ${dir}/decode_${dset} ${dir}/decode_${dset}_rescore || exit 1
   ) || touch $dir/.error &
  done
  wait
  [ -f $dir/.error ] && echo "$0: there was a problem while decoding" && exit 1
fi

exit 0;
