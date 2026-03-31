#!/bin/bash

WORK_DIR=/opt/llama-qwen.service.d
LLAMA_SERVER=$WORK_DIR/llama-server
CHAT_MODEL=$WORK_DIR/models/qwen2.5-coder-14b-instruct-q4_k_m.gguf
AUTOCOMP_MODEL=$WORK_DIR/models/qwen2.5-coder-1.5b-instruct-q8_0.gguf

# amd 기준으로 작성됨. amd가 이니면 아래의 export 주석 해도 될듯.
export HSA_OVERRIDE_GFX_VERSION=11.0.0

# 1. Chat용 14B 모델
$LLAMA_SERVER \
    -m $CHAT_MODEL \
    -ngl 99 \
    -c 8192 \
    --port 8080 \
    --host 0.0.0.0 &

# 2. Autocomplete용 1.5B 모델 (FIM 필수)
$LLAMA_SERVER \
    -m $AUTOCOMP_MODEL \
    -c 4096 \
    --port 8081 \
    --n-gpu-layers 99 \
    --host 0.0.0.0 &

wait