#!/bin/bash


REQUIRED_PKGS=("cmake" "make" "gcc" "g++" "git" "wget" "curl")

TARGET_GPU=gfx1151 # 디폴트

ROOT_DIR=$(pwd)
WORK_DIR=$ROOT_DIR/tmp

source $ROOT_DIR/script_part/build_llama_cpp
source $ROOT_DIR/script_part/install_func

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
BUILD_TARGET="default"
while [ "$#" -gt 0 ]; do
  OPTION="$1"
  shift

  case "$OPTION" in
    --vulkan)
      echo "[LLAMA.CPP] Using vulkan..."
      REQUIRED_PKGS+=("libvulkan-dev")
      REQUIRED_PKGS+=("vulkan-tools")
      LLAMACPP_BLD_FLAG="-DGGML_NATIVE=OFF -DGGML_VULKAN=ON -DLLAMA_BUILD_TESTS=OFF -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON"
      BUILD_TARGET="vulkan"
      break
      ;;
    --gfx*)
      echo "[LLAMA.CPP] Using ROCm..."
      GFX_NUM="${OPTION#--gfx}"
      if is_valid_gfx "$GFX_NUM"; then
        # LLAMACPP_BLD_FLAG="-DGGML_HIP=ON -DGGML_HIP_ROCWMMA_FATTN=ON -DAMDGPU_TARGETS=gfx${GFX_NUM} -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_TESTS=OFF -DGGML_NATIVE=OFF -DGGML_CUDA=ON -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DLLAMA_BUILD_TESTS=OFF -DCMAKE_CUDA_ARCHITECTURES=native -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined -DCMAKE_HIP_COMPILER=-DCMAKE_HIP_COMPILER=/opt/rocm-7.2.1/bin/hipcc"
        LLAMACPP_BLD_FLAG="-DGGML_HIP=ON -DGGML_HIP_ROCWMMA_FATTN=ON -DAMDGPU_TARGETS=gfx${GFX_NUM} -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_TESTS=OFF -DCMAKE_HIP_COMPILER=/opt/rocm-7.2.1/lib/llvm/bin/clang"
        REQUIRED_PKGS+=("gpg")
        REQUIRED_PKGS+=("dkms")
        BUILD_TARGET="rocm"
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
      # not tested.
      # DCMAKE_CUDA_ARCHITECTURES is not specified.      
      LLAMACPP_BLD_FLAG="-DGGML_NATIVE=OFF -DGGML_CUDA=ON -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DLLAMA_BUILD_TESTS=OFF -DCMAKE_CUDA_ARCHITECTURES=native -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined "
      BUILD_TARGET="cuda"
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
  (  
    REAL_USER=$SUDO_USER
  sudo -u "$REAL_USER" bash <<EOF
    mkdir -p $WORK_DIR
    mkdir -p $WORK_DIR/bin
    cd $WORK_DIR

    git clone --branch $LLAMACPP_TAG ${LLAMACPP_REPO} 

    cd llama.cpp
    echo "cmake -B build $LLAMACPP_BLD_FLAG"
    cmake -B build $LLAMACPP_BLD_FLAG
    

    cmake --build build --config Release -j16

    cp build/bin/llama-server $WORK_DIR/bin
    cp build/bin/llama-cli $WORK_DIR/bin

EOF


  )
}


if [[ $EUID -ne 0 ]]; then
   echo "❌ need root permission."
   
   echo "run: sudo $0"
   exit 1
fi

build_llamacpp $SUDO_USER $WORK_DIR $LLAMACPP_BLD_FLAG

# get_qwen_model $WORK_DIR
install_model $WORK_DIR
install_service



# cmake -B build -DGGML_HIP=ON -DGGML_HIP_ROCWMMA_FATTN=ON -DAMDGPU_TARGETS=gfx1151 -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_TESTS=OFF -DGGML_NATIVE=OFF -DGGML_CUDA=ON -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DLLAMA_BUILD_TESTS=OFF -DCMAKE_CUDA_ARCHITECTURES=native -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined -DCMAKE_HIP_COMPILER=-DCMAKE_HIP_COMPILER=/opt/rocm-7.2.1/bin/hipcc

# cmake -B build -DGGML_HIP=ON -DGGML_HIP_ROCWMMA_FATTN=ON -DAMDGPU_TARGETS=gfx1151 -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_TESTS=OFF -DGGML_NATIVE=OFF -DGGML_CUDA=ON -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DLLAMA_BUILD_TESTS=OFF -DCMAKE_CUDA_ARCHITECTURES=native -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined -DCMAKE_HIP_COMPILER=/opt/rocm-7.2.1/bin/hipcc

# cmake -S . -B build 