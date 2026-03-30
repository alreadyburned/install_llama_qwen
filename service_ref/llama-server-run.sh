#!/bin/bash

ExecStart=/home/nysa21/models/llama-server \
    -m /home/nysa21/models/qwen2.5-coder-14b-instruct-q4_k_m.gguf \
    -ngl 49 \
    -c 8192 \
    --port 8080 \
    --host 0.0.0.0

WORK_DIR=/opt/opt/llama-qwen.service.d
LLAMA_SERVER=$WORK_DIR/llama-server
CHAT_MODEL=$WORK_DIR/models/qwen2.5-coder-14b-instruct-q4_k_m.gguf
AUTOCOMP_MODEL=$WORK_DIR/models/qwen2.5-coder-1.5b-instruct-q8_0.gguf

# 1. Chat용 14B 모델 실행 (Port 8080)
$LLAMA_SERVER \
    -m $CHAT_MODEL \
    -c 8192 \
    --port 8080 \
    --n-gpu-layers 99 &

# 2. Autocomplete용 1.5B 모델 실행 (Port 8081)
$LLAMA_SERVER \
    -m $AUTOCOMP_MODEL \
    -c 4096 \
    --port 8081 \
    --n-gpu-layers 99 &

# 두 프로세스가 종료되지 않도록 대기
wait