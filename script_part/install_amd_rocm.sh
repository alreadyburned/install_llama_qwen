#!/bin/bash


ROCM_PACKAGES=(
    "rocm-hip-runtime7.2.1"
    "rocm-opencl-runtime7.2.1"
    "rocm-hip-sdk7.2.1"
    "rocblas-dev7.2.1"
    "hip-dev7.2.1"
    "rocm-device-libs7.2.1"
    "rocm-cmake7.2.1"
)
MISSING_ROCM_PACKAGES=()

check_rocm_package()
{
    MISSING_ROCM_PACKAGES=()

    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        # dpkg -l로 패키지 상태 확인 (ii는 설치됨을 의미)
        if dpkg -l | grep -q "^ii  $pkg "; then
            echo "[ OK ] $pkg"
        else
            echo "[ NO ] $pkg"
            MISSING_ROCM_PACKAGES+=("$pkg")
        fi
    done

    # build-essential is a package group, so its components (make, gcc, g++) are checked
    if [ ${#MISSING_ROCM_PACKAGES[@]} -ne 0 ]; then
        echo "❌ Error: The following required tools are not installed: "
        printf "[%s]\n" "${MISSING_ROCM_PACKAGES[@]}"
        return 1
    fi
    return 0
}

install_missing_rocm_package()
{
    local PKG_LISTS=("$@")
    wget https://repo.radeon.com/amdgpu-install/6.3.1/ubuntu/noble/amdgpu-install_6.3.60301-1_all.deb
    for pkg in "${PKG_LISTS[@]}"; do
       echo "apt install -y $pkg"
    done
}
# install_missing_rocm_package "${REQUIRED_PACKAGES[@]}"