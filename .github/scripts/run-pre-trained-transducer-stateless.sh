#!/usr/bin/env bash

set -e

log() {
  # This function is from espnet
  local fname=${BASH_SOURCE[1]##*/}
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $*"
}

cd egs/librispeech/ASR

repo_url=https://huggingface.co/csukuangfj/icefall-asr-librispeech-transducer-stateless-bpe-500-2022-02-07

log "Downloading pre-trained model from $repo_url"
git lfs install
git clone $repo_url
repo=$(basename $repo_url)

log "Display test files"
tree $repo/
ls -lh $repo/test_wavs/*.wav

for sym in 1 2 3; do
  log "Greedy search with --max-sym-per-frame $sym"

  ./transducer_stateless/pretrained.py \
    --method greedy_search \
    --max-sym-per-frame $sym \
    --checkpoint $repo/exp/pretrained.pt \
    --tokens $repo/data/lang_bpe_500/tokens.txt \
    $repo/test_wavs/1089-134686-0001.wav \
    $repo/test_wavs/1221-135766-0001.wav \
    $repo/test_wavs/1221-135766-0002.wav
done

for method in fast_beam_search modified_beam_search beam_search; do
  log "$method"

  ./transducer_stateless/pretrained.py \
    --method $method \
    --beam-size 4 \
    --checkpoint $repo/exp/pretrained.pt \
    --tokens $repo/data/lang_bpe_500/tokens.txt \
    $repo/test_wavs/1089-134686-0001.wav \
    $repo/test_wavs/1221-135766-0001.wav \
    $repo/test_wavs/1221-135766-0002.wav
done

echo "GITHUB_EVENT_NAME: ${GITHUB_EVENT_NAME}"
echo "GITHUB_EVENT_LABEL_NAME: ${GITHUB_EVENT_LABEL_NAME}"
if [[ x"${GITHUB_EVENT_NAME}" == x"schedule" || x"${GITHUB_EVENT_LABEL_NAME}" == x"run-decode"  ]]; then
  mkdir -p transducer_stateless/exp
  ln -s $PWD/$repo/exp/pretrained.pt transducer_stateless/exp/epoch-999.pt
  ln -s $PWD/$repo/data/lang_bpe_500 data/

  ls -lh data
  ls -lh transducer_stateless/exp

  log "Decoding test-clean and test-other"

  # use a small value for decoding with CPU
  max_duration=100

  for method in greedy_search fast_beam_search modified_beam_search; do
    log "Decoding with $method"

    ./transducer_stateless/decode.py \
      --decoding-method $method \
      --epoch 999 \
      --avg 1 \
      --max-duration $max_duration \
      --exp-dir transducer_stateless/exp
  done

  rm transducer_stateless/exp/*.pt
fi
