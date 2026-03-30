#!/bin/bash

WORK_DIR=/opt/llama-qwen.service.d
LLAMA_SERVER=$WORK_DIR/llama-server
CHAT_MODEL=$WORK_DIR/models/qwen2.5-coder-14b-instruct-q4_k_m.gguf
AUTOCOMP_MODEL=$WORK_DIR/models/qwen2.5-coder-1.5b-instruct-q8_0.gguf

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