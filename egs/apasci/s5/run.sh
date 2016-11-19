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

. ./cmd.sh
[ -f path.sh ] && . ./path.sh
set -e

# Acoustic model parameters (from TIMIT recipe)
numLeavesTri1=2500
numGaussTri1=15000
numLeavesMLLT=2500
numGaussMLLT=15000
numLeavesSAT=2500
numGaussSAT=15000
numGaussUBM=400
numLeavesSGMM=7000
numGaussSGMM=9000

feats_nj=10
train_nj=30
decode_nj=5

stage=0

. utils/parse_options.sh # accept options

echo ============================================================================
echo "                Data & Lexicon & Language Preparation                     "
echo ============================================================================

apasci=$HOME/corpora/APASCI/1.0
coris_lm=$HOME/corpora/CORIS4word2vecNOMWE_APO.arpa.lm.bz2

# Data preparation
if [ $stage -le 0 ]; then
    local/apasci_data_prep.sh $apasci || exit 1
fi

# Dict preparation
if [ $stage -le 1 ]; then
    local/apasci_dict_prep.sh $coris_lm || exit 1
fi

# Lang preparation
if [ $stage -le 2 ]; then
    utils/prepare_lang.sh data/local/dict "<SIL>" data/local/lang_tmp data/lang
fi

# time spent here: 37m55.241s

# Create LM (G.fst)
if [ $stage -le 3 ]; then
    local/format_lm.sh $coris_lm
fi

echo ============================================================================
echo "      MFCC / PLP Feature Extration & CMVN for Training and Test set       "
echo ============================================================================

# Now make MFCC features.
mfccdir=mfcc
plpdir=plp

if [ $stage -le 4 ]; then
    for x in train dev test; do 
	steps/make_mfcc.sh --cmd "$train_cmd" --nj $feats_nj data/$x exp/make_mfcc/$x $mfccdir
	# steps/make_plp.sh --cmd "$train_cmd" --nj $feats_nj data/$x exp/make_plp/$x $plpdir
	steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
	# steps/compute_cmvn_stats.sh data/$x exp/make_plp/$x $plpdir
	utils/validate_data_dir.sh data/$x
	utils/fix_data_dir.sh data/$x
    done
fi

echo ============================================================================
echo "                     MonoPhone Training & Decoding                        "
echo ============================================================================

if [ $stage -le 5 ]; then
    steps/train_mono.sh  --nj "$train_nj" --cmd "$train_cmd" data/train data/lang exp/mono
    utils/mkgraph.sh --mono data/lang_test_bg exp/mono exp/mono/graph

    steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
		    exp/mono/graph data/dev exp/mono/decode_dev

    steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
		    exp/mono/graph data/test exp/mono/decode_test
fi

echo ============================================================================
echo "           tri1 : Deltas + Delta-Deltas Training & Decoding               "
echo ============================================================================

if [ $stage -le 6 ]; then
    steps/align_si.sh --boost-silence 1.25 --nj "$train_nj" --cmd "$train_cmd" \
	data/train data/lang exp/mono exp/mono_ali

    # Train tri1, which is deltas + delta-deltas, on train data.
    steps/train_deltas.sh --cmd "$train_cmd" \
	$numLeavesTri1 $numGaussTri1 data/train data/lang exp/mono_ali exp/tri1

    utils/mkgraph.sh data/lang_test_bg exp/tri1 exp/tri1/graph

    steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
	exp/tri1/graph data/dev exp/tri1/decode_dev

    steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
	exp/tri1/graph data/test exp/tri1/decode_test
fi

echo ============================================================================
echo "                 tri2 : LDA + MLLT Training & Decoding                    "
echo ============================================================================

if [ $stage -le 7 ]; then
    steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
	data/train data/lang exp/tri1 exp/tri1_ali

    steps/train_lda_mllt.sh --cmd "$train_cmd" \
	--splice-opts "--left-context=3 --right-context=3" \
	$numLeavesMLLT $numGaussMLLT data/train data/lang exp/tri1_ali exp/tri2

    utils/mkgraph.sh data/lang_test_bg exp/tri2 exp/tri2/graph

    steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
	exp/tri2/graph data/dev exp/tri2/decode_dev

    steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
	exp/tri2/graph data/test exp/tri2/decode_test
fi

echo ============================================================================
echo "              tri3 : LDA + MLLT + SAT Training & Decoding                 "
echo ============================================================================

if [ $stage -le 8 ]; then
    # Align tri2 system with train data.
    steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
	--use-graphs true data/train data/lang exp/tri2 exp/tri2_ali

    # From tri2 system, train tri3 which is LDA + MLLT + SAT.
    steps/train_sat.sh --cmd "$train_cmd" \
	$numLeavesSAT $numGaussSAT data/train data/lang exp/tri2_ali exp/tri3

    utils/mkgraph.sh data/lang_test_bg exp/tri3 exp/tri3/graph

    steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" \
	exp/tri3/graph data/dev exp/tri3/decode_dev

    steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" \
	exp/tri3/graph data/test exp/tri3/decode_test
fi

echo ============================================================================
echo "                        SGMM2 Training & Decoding                         "
echo ============================================================================

if [ $stage -le 9 ]; then
    steps/align_fmllr.sh --nj "$train_nj" --cmd "$train_cmd" \
	data/train data/lang exp/tri3 exp/tri3_ali

    #exit 0 # From this point you can run Karel's DNN : local/nnet/run_dnn.sh 

    steps/train_ubm.sh --cmd "$train_cmd" \
	$numGaussUBM data/train data/lang exp/tri3_ali exp/ubm4

    steps/train_sgmm2.sh --cmd "$train_cmd" $numLeavesSGMM $numGaussSGMM \
	data/train data/lang exp/tri3_ali exp/ubm4/final.ubm exp/sgmm2_4

    utils/mkgraph.sh data/lang_test_bg exp/sgmm2_4 exp/sgmm2_4/graph

    steps/decode_sgmm2.sh --nj "$decode_nj" --cmd "$decode_cmd"\
	--transform-dir exp/tri3/decode_dev exp/sgmm2_4/graph data/dev \
	exp/sgmm2_4/decode_dev

    steps/decode_sgmm2.sh --nj "$decode_nj" --cmd "$decode_cmd"\
	--transform-dir exp/tri3/decode_test exp/sgmm2_4/graph data/test \
	exp/sgmm2_4/decode_test
fi

echo ============================================================================
echo "                    MMI + SGMM2 Training & Decoding                       "
echo ============================================================================

if [ $stage -le 10 ]; then
    steps/align_sgmm2.sh --nj "$train_nj" --cmd "$train_cmd" \
	--transform-dir exp/tri3_ali --use-graphs true --use-gselect true \
	data/train data/lang exp/sgmm2_4 exp/sgmm2_4_ali

    steps/make_denlats_sgmm2.sh --nj "$train_nj" --sub-split "$train_nj" \
	--acwt 0.2 --lattice-beam 10.0 --beam 18.0 \
	--cmd "$decode_cmd" --transform-dir exp/tri3_ali \
	data/train data/lang exp/sgmm2_4_ali exp/sgmm2_4_denlats

    steps/train_mmi_sgmm2.sh --acwt 0.2 --cmd "$decode_cmd" \
	--transform-dir exp/tri3_ali --boost 0.1 --drop-frames true \
	data/train data/lang exp/sgmm2_4_ali exp/sgmm2_4_denlats exp/sgmm2_4_mmi_b0.1

    for iter in 1 2 3 4; do
	steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
		--transform-dir exp/tri3/decode_dev data/lang_test_bg data/dev \
		exp/sgmm2_4/decode_dev exp/sgmm2_4_mmi_b0.1/decode_dev_it$iter

	steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
		--transform-dir exp/tri3/decode_test data/lang_test_bg data/test \
		exp/sgmm2_4/decode_test exp/sgmm2_4_mmi_b0.1/decode_test_it$iter
    done
fi

exit 0

echo ============================================================================
echo "                    DNN Hybrid Training & Decoding                        "
echo ============================================================================

# DNN hybrid system training parameters
dnn_mem_reqs="--mem 1G"
dnn_extra_opts="--num_epochs 20 --num-epochs-extra 10 --add-layers-period 1 --shrink-interval 3"

if [ $stage -le 11 ]; then
    steps/nnet2/train_tanh.sh --mix-up 5000 --initial-learning-rate 0.015 \
	--final-learning-rate 0.002 --num-hidden-layers 2  \
	--num-jobs-nnet "$train_nj" --cmd "$train_cmd" "${dnn_train_extra_opts[@]}" \
	data/train data/lang exp/tri3_ali exp/tri4_nnet

    [ ! -d exp/tri4_nnet/decode_dev ] && mkdir -p exp/tri4_nnet/decode_dev
    decode_extra_opts=(--num-threads 6)
    steps/nnet2/decode.sh --cmd "$decode_cmd" --nj "$decode_nj" "${decode_extra_opts[@]}" \
	--transform-dir exp/tri3/decode_dev exp/tri3/graph data/dev \
	exp/tri4_nnet/decode_dev | tee exp/tri4_nnet/decode_dev/decode.log

    [ ! -d exp/tri4_nnet/decode_test ] && mkdir -p exp/tri4_nnet/decode_test
    steps/nnet2/decode.sh --cmd "$decode_cmd" --nj "$decode_nj" "${decode_extra_opts[@]}" \
	--transform-dir exp/tri3/decode_test exp/tri3/graph data/test \
	exp/tri4_nnet/decode_test | tee exp/tri4_nnet/decode_test/decode.log
fi

echo ============================================================================
echo "                    System Combination (DNN+SGMM)                         "
echo ============================================================================

if [ $stage -le 12 ]; then
    for iter in 1 2 3 4; do
	local/score_combine.sh --cmd "$decode_cmd" \
		data/dev data/lang_test_bg exp/tri4_nnet/decode_dev \
		exp/sgmm2_4_mmi_b0.1/decode_dev_it$iter exp/combine_2/decode_dev_it$iter

	local/score_combine.sh --cmd "$decode_cmd" \
		data/test data/lang_test_bg exp/tri4_nnet/decode_test \
		exp/sgmm2_4_mmi_b0.1/decode_test_it$iter exp/combine_2/decode_test_it$iter
    done
fi

echo ============================================================================
echo "               DNN Hybrid Training & Decoding (Karel's recipe)            "
echo ============================================================================

if [ $stage -le 13 ]; then
    local/nnet/run_dnn.sh
fi

echo ============================================================================
echo "               DNN Hybrid Training & Decoding (nnet3)                     "
echo ============================================================================

if [ $stage -le 14 ]; then
    # The nnet3 TDNN recipe
    local/nnet3/run_tdnn.sh
    # local/chain/run_tdnn.sh
fi

echo ============================================================================
echo "                    Getting Results [see RESULTS file]                    "
echo ============================================================================

bash RESULTS

echo ============================================================================
echo "Finished successfully on" `date`
echo ============================================================================

exit 0
