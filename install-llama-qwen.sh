#!/bin/bash

LLAMACPP_TAG=b8580
LLAMACPP_REPO=https://github.com/ggml-org/llama.cpp.git
# 
QWEN2.5_CHAT_URL=https://huggingface.co/Qwen/Qwen2.5-Coder-14B-Instruct-GGUF/resolve/main/qwen2.5-coder-14b-instruct-q4_k_m.gguf
QWEN2.5_AUTOCMPLT_URL=https://huggingface.co/unsloth/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-1.5B-Instruct-Q8_0.gguf


REQUIRED_PKGS=("cmake" "make" "gcc" "g++" "git" "wget" "curl")

TARGET_GPU=gfx1151 # 

ROOT_DIR=$(pwd)
WORK_DIR=$ROOT_DIR/tmp

LLAMACPP_BLD_FLAG=""
    
print_usage(){
    echo " usage : $0 [llama.cpp build option] "
    echo "--vulkan : using vulkan "
    echo "--gfx*   : using ROCm (example --gfx1151 : radeon ai max+ gpu series)"
    echo "--nvidia : using cuda"
    echo "(no option) : build default"
    echo "(Warning: Only the first option will be used.)"
}

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

while [ "$#" -gt 0 ]; do
  OPTION="$1"
  shift

  case "$OPTION" in
    --vulkan)
      echo "[LLAMA.CPP] Using vulkan..."
      REQUIRED_PKGS+=("libvulkan-dev")
      REQUIRED_PKGS+=("vulkan-tools")
      LLAMACPP_BLD_FLAG="-DGGML_VULKAN=ON"
      break
      ;;
    --gfx*)
      echo "[LLAMA.CPP] Using ROCm..."
      GFX_NUM="${OPTION#--gfx}"
      if is_valid_gfx "$GFX_NUM"; then
        LLAMACPP_BLD_FLAG="-DGGML_HIPBLAS=ON -DAMDGPU_TARGETS=gfx${GFX_NUM} -DGGML_HIP_ROCWMMA_FATTN=ON"
        REQUIRED_PKGS+=("gpg")
        REQUIRED_PKGS+=("dkms")
      else
        echo "❌ ERROR: 'gfx$GFX_NUM' is invalid."
        echo "Valid GFX:"
        printf "%s " "${VALID_GFX[@]}"
        echo # To add a newline at the end
        exit 1
      fi
      break
      ;;
    --nvidia)
      echo "[LLAMA.CPP] Using Cuda..."
      LLAMACPP_BLD_FLAG="-DGGML_CUDA=ON"
      break
      ;;
    --help)
      print_usage
      exit 1
      ;;
    *)
      echo "⚠️ Invalid Option: $OPTION"
      print_usage
      exit 1
      ;;
  esac
done



MISSING_PKGS=()
for pkg in "${REQUIRED_PKGS[@]}"; do
  if ! command -v "$pkg" &> /dev/null; then
    if [ "$pkg" = "gpg" ]; then
      MISSING_PKGS+=("gnupg2")
    else
      MISSING_PKGS+=("$pkg")
    fi
  fi
done

# build-essential is a package group, so its components (make, gcc, g++) are checked
if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
  echo "❌ Error: The following required tools are not installed: "
    printf "[%s]\n" "${MISSING_PKGS[@]}"
  exit 1
fi

build_llamacpp()
{
  mkdir -p $WORK_DIR
  mkdir -p $WORK_DIR/bin
  cd $WORK_DIR

  git clone --branch $LLAMACPP_TAG ${LLAMACPP_REPO} 

  cd llama.cpp
  cmake -B build $LLAMACPP_BLD_FLAG

  cmake --build build --config Release --parallel $(nproc)

  cp build/bin/llama-server $WORK_DIR/bin
  cp build/bin/llama-cli $WORK_DIR/bin

  cd $ROOT_DIR
}

get_qwen_model()
{
  mkdir -p $WORK_DIR
  mkdir -p $WORK_DIR/models
  cd $WORK_DIR/models

  wget $QWEN2.5_CHAT_URL
  wget $QWEN2.5_AUTOCMPLT_URL  

  cd $ROOT_DIR
}

install_model()
{
  mkdir -p /opt/llama-qwen.service.d
  mkdir -p /opt/llama-qwen.service.d/models

  cp $WORK_DIR/models/* /opt/llama-qwen.service.d/models
  cp $WORK_DIR/bin /opt/llama-qwen.service.d
}

install_service()
{

}

build_llamacpp

get_qwen_model


