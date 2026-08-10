#!/bin/bash

LLAMACPP_TAG="gfx11-rocm-nightly-20260805"
LLAMACPP_REPO="https://github.com/AMD-Ecosystem/llama.cpp"

DEFAULT_GFX_NUM="1151"
GFX_NUM="$DEFAULT_GFX_NUM"



# 1. 유효한 gfx 아키텍처 목록 정의 (Strix Halo 포함)
VALID_GFX=("1150" "1151" "1103" "1100" "1101" "1030" "1130" "1131" "1133" "1010" "1012" "90a" "940" "942")

is_valid_gfx() {
    local input=$1
    for valid in "${VALID_GFX[@]}"; do
        if [[ "$input" == "$valid" ]]; then
            return 0 # 유효함
        fi
    done
    return 1 # 유효하지 않음
}

print_usage() {
    echo "usage: $0 [--gfx*]"
    echo "example: $0 --gfx1151"
    echo "(no option): default gfx${DEFAULT_GFX_NUM}"
}

if [[ -n "${1:-}" ]]; then
    case "$1" in
      --gfx*)
        GFX_NUM="${1#--gfx}"
        if ! is_valid_gfx "$GFX_NUM"; then
          echo "❌ ERROR: 'gfx$GFX_NUM' is invalid."
          echo "Valid GFX:"
          printf "%s " "${VALID_GFX[@]}"
          echo
          exit 1
      fi
        ;;
      --help)
        print_usage
        exit 0
        ;;
      *)
        echo "⚠️ Invalid Option: $1"
        print_usage
        exit 1
        ;;
    esac
  fi

# DGGML_NATIVE : 내 cpu 아키텍처에 맞게 최적화된 빌드 옵션을 활성화합니다. (예: AVX2, AVX512 등)
# DGGML_CPU_ALL_VARIANTS : 모든 CPU 아키텍처에 대한 빌드 옵션을 활성화합니다. (예: AVX2, AVX512 등)
# DGGML_BACKEND_DL : 동적 라이브러리 로딩을 활성화 ON/OFF
# DLLAMA_CURL : 네트워크로 모델을 다운로드할 수 있도록 curl 지원을 활성화합니다. (ON/OFF)

LLAMACPP_BLD_FLAG=""
LLAMACPP_BLD_FLAG+="-DGGML_HIP=ON "
LLAMACPP_BLD_FLAG+="-DGGML_HIP_ROCWMMA_FATTN=ON "
LLAMACPP_BLD_FLAG+="-DGGML_NATIVE=ON "
LLAMACPP_BLD_FLAG+="-DAMDGPU_TARGETS=gfx${GFX_NUM} "
LLAMACPP_BLD_FLAG+="-DGGML_BACKEND_DL=OFF "
LLAMACPP_BLD_FLAG+="-DLLAMA_CURL=OFF "
LLAMACPP_BLD_FLAG+="-DCMAKE_BUILD_TYPE=Release "
LLAMACPP_BLD_FLAG+="-DLLAMA_BUILD_TESTS=OFF "
LLAMACPP_BLD_FLAG+="-DCMAKE_CXX_COMPILER="$(hipconfig -l)/clang "
LLAMACPP_BLD_FLAG+="-DHIP_PATH="$(hipconfig -R)"


build_llamacpp()
{
    local REAL_USER=$1
    local WORK_PATH=$2
    local EXTRA_FLAG=$3
    
  (  
    # 사용자 권한으로 빌드.
    REAL_USER=$SUDO_USER
  sudo -u "$REAL_USER" bash <<EOF
    mkdir -p $WORK_PATH
    mkdir -p $WORK_PATH/bin
    cd $WORK_PATH

    git clone --branch $LLAMACPP_TAG ${LLAMACPP_REPO} 

    cd llama.cpp
    
    echo "cmake -S . -B build $EXTRA_FLAG"
    cmake -S . -B build $EXTRA_FLAG

    # cmake --build build --config Release -j($nproc)
    cmake --build build --config Release --target llama-cli -j16
    cmake --build build --config Release --target llama-server -j16
    cmake --build build --config Release --target llama-bench -j16

    sleep 1
    rm $WORK_PATH/bin/*
    
    cp build/bin/* $WORK_PATH/bin
    # cp build/bin/llama-cli $WORK_PATH/bin
EOF


  )
}
ROOT_DIR=$(pwd)
WORK_DIR=$ROOT_DIR/tmp

build_llamacpp $SUDO_USER $WORK_DIR $LLAMACPP_BLD_FLAG
