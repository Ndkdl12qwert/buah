#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ba=$(find $HOME/bashbuild -name "bash")
if [ $? -eq 0 ]; then
    cp -r ${ba} bashelf/ || mkdir ~/bashelf || cp -r ${ba} bashelf/
fi
if [[ -d "$HOME/bashbuild" ]]; then
    rm -rf "$HOME/bashbuild"
fi
error_exit() {
    local log_content=""
    echo -e "${RED}[ERROR]${NC} $1"
    
    if [[ -d "$HOME/bashbuild" ]]; then
        log_content=$(find "$HOME/bashbuild" -name "build.log" -exec cat {} \; 2>/dev/null)
    fi
    
    if [[ -n "$log_content" ]]; then
        echo -e "${YELLOW}=== Build log ===${NC}"
        echo "$log_content"
    else
        echo "No build logs found."
    fi
    
    exit 1
}

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${YELLOW}Missing: $1${NC}"
        return 1
    fi
    return 0
}

install_dependencies() {
    local missing=()
    for cmd in make wget tar gcc; do
        if ! check_dependency "$cmd"; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing dependencies: ${missing[*]}"
        read -p "Install them? (Y/n) " answer
        if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
            sudo apt update
            sudo apt install build-essential wget tar -y
        else
            error_exit "Dependencies required. Exiting."
        fi
    fi
}

install_risc-v32_gnu() {
    echo -e "${GREEN}I'm very sorry, for your experience, I had to spend a few hours making you compile this damn toolchain. Apologies again.${NC}"
    sleep 2
    local version="$1"
    if ! [[ ${version} == "bash-5.3" ]]; then
        find . -name riscv32-unknown-linux-gnu-gcc &> /dev/null
        if [ $? -eq 0 ]; then
            echo "RISC-V 32-bit toolchain already installed."
            return
        fi
    
        mkdir -p $HOME/riscvbuild && cd $HOME/riscvbuild
        echo "${GREEN}This may take some time... For the sake of your architecture, I have no choice.${NC}"
        slepp 2
        echo "${GREEN}This might take several hours, it's okay, it only happens the first time.${NC}"
        git clone --recursive https://github.com/riscv-collab/riscv-gnu-toolchain
        cd ${pwd}/riscv-gnu-toolchain
        mkdir build && cd build
        ../configure --prefix=$HOME/riscv32 --with-arch=rv32gc --with-abi=ilp32d
        read -p "Enter number of cores for compilation [default: $(nproc)]Recommendation 3: " cores
        cores=${cores:-$(nproc)}
        make -j"$cores" V=1 2>&1 | tee build.log
        if ! command -v riscv32-unknown-linux-gnu-gcc &> /dev/null; then
            error_exit "RISC-V 32-bit toolchain installation failed"
        fi
    else
        find . -name riscv32-unknown-linux-gnu-gcc &> /dev/null
        if [ $? -eq 0 ]; then
            echo "RISC-V 32-bit toolchain already installed."
            return
        fi
    
        mkdir -p $HOME/riscvbuild && cd $HOME/riscvbuild
        echo "${GREEN}This may take some time... For the sake of your architecture, I have no choice.${NC}"
        slepp 2
        echo "${GREEN}This might take several hours, it's okay, it only happens the first time.${NC}"
        git clone --recursive https://github.com/riscv-collab/riscv-gnu-toolchain
        cd ${pwd}/riscv-gnu-toolchain
        git checkout 2023.10.12
        git submodule update --init --recursive
        mkdir build && cd build
        ../configure \
            --prefix=$HOME/riscv32-gcc13 \
            --target=riscv32-unknown-linux-gnu \
            --with-arch=rv32gc \
            --with-abi=ilp32d
        read -p "Enter number of cores for compilation [default: $(nproc)]Recommendation 3: " cores
        cores=${cores:-$(nproc)}
        make -j"$cores" V=1 2>&1 | tee build.log
        if ! command -v riscv32-unknown-linux-gnu-gcc &> /dev/null; then
            error_exit "RISC-V 32-bit toolchain installation failed"
        fi
    fi
}

build_bash_version_DX() {
    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    # 配置和编译
    echo "Configuring..."
    ./configure --prefix=/usr/local || error_exit "Configure failed"
    
    echo "Compiling with $cores cores..."
    make -j"$cores" 2>&1 | tee build.log
    
    # 检查编译结果（更可靠的方法）
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
}

build_bash_version_SX() {
    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    # 配置和编译
    echo "Configuring..."
    ./configure --prefix=/usr/local --enable-static-link --disable-shared  --enable-static LDFLAGS="-static -static-libgcc" \
    CPPFLAGS="-static"|| error_exit "Configure failed"
    
    echo "Compiling with $cores cores..."
    make -j"$cores" CFLAGS="-static" LDFLAGS="-static" 2>&1 | tee build.log
    
    # 检查编译结果（更可靠的方法）
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
}

build_bash_version_DA() {
    if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
        sudo apt update
        sudo apt install -y gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
    fi
    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    # 配置和编译
    echo "Configuring..."
    ./configure \
    --host=aarch64-linux-gnu \
    --prefix=/usr/local || error_exit "Configure failed"
    
    echo "Compiling with $cores cores..."
    make -j"$cores" CC=aarch64-linux-gnu-gcc 2>&1 | tee build.log
    
    # 检查编译结果（更可靠的方法）
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
}

build_bash_version_SA() {
    if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
        sudo apt update
        sudo apt install -y gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
    fi
    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    # 配置和编译
    echo "Configuring..."
    ./configure \
    --host=aarch64-linux-gnu \
    --enable-static-link \
    --without-bash-malloc || error_exit "Configure failed"
    
    echo "Compiling with $cores cores..."
    make -j"$cores" CC=aarch64-linux-gnu-gcc 2>&1 | tee build.log
    
    # 检查编译结果（更可靠的方法）
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
}

build_bash_version_DI() {
    if ! command -v i686-linux-gnu-gcc &> /dev/null; then
        sudo apt update
        sudo apt install -y gcc-i686-linux-gnu binutils-i686-linux-gnu
    fi
    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    # 配置和编译
    echo "Configuring..."
    ./configure --host=i686-linux-gnu --prefix=/usr/local || error_exit "Configure failed"
    
    echo "Compiling with $cores cores..."
    make -j"$cores" CC=i686-linux-gnu-gcc 2>&1 | tee build.log
    
    # 检查编译结果（更可靠的方法）
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
}

build_bash_version_SI() {
    if ! command -v i686-linux-gnu-gcc &> /dev/null; then
        sudo apt update
        sudo apt install -y gcc-i686-linux-gnu binutils-i686-linux-gnu
    fi
    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    # 配置和编译
    echo "Configuring..."
    ./configure \
    --host=i686-linux-gnu \
    --enable-static-link \
    --without-bash-malloc || error_exit "Configure failed"
    
    echo "Compiling with $cores cores..."
    make -j"$cores" CC=i686-linux-gnu-gcc 2>&1 | tee build.log
    
    # 检查编译结果（更可靠的方法）
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
}

build_bash_version_DA3() {
read -p "Hard floating-point / soft floating-point? >>" fpu
if [[ "$fpu" == "Hard" || "$fpu" == "hard" ]]; then
    if ! command -v arm-linux-gnueabihf-gcc &> /dev/null; then
        sudo apt update
        sudo apt install -y gcc-arm-linux-gnueabihf binutils-arm-linux-gnueabihf
    fi
    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    # 配置和编译
    echo "Configuring..."
    ./configure \
    --host=arm-linux-gnueabihf \
    --prefix=/usr/local || error_exit "Configure failed"
    
    echo "Compiling with $cores cores..."
    make -j"$cores" CC=arm-linux-gnueabihf-gcc 2>&1 | tee build.log
    
    # 检查编译结果（更可靠的方法）
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
else
    if ! command -v arm-linux-gnueabi-gcc &> /dev/null; then
        sudo apt update
        sudo apt install -y gcc-arm-linux-gnueabi binutils-arm-linux-gnueabi
    fi
    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    # 配置和编译
    echo "Configuring..."
    ./configure \
    --host=arm-linux-gnueabi \
    --prefix=/usr/local || error_exit "Configure failed"
    
    echo "Compiling with $cores cores..."
    make -j"$cores" CC=arm-linux-gnueabi-gcc 2>&1 | tee build.log
    
    # 检查编译结果（更可靠的方法）
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
fi
}

build_bash_version_SA3() {
read -p "Hard floating-point / soft floating-point? >>" fpu
if [[ "$fpu" == "Hard" || "$fpu" == "hard" ]]; then
    if ! command -v arm-linux-gnueabihf-gcc &> /dev/null; then
        sudo apt update
        sudo apt install -y gcc-arm-linux-gnueabihf binutils-arm-linux-gnueabihf
    fi
    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    # 配置和编译
    echo "Configuring..."
    ./configure \
    --host=arm-linux-gnueabihf \
    --enable-static-link \
    --without-bash-malloc || error_exit "Configure failed"
    
    echo "Compiling with $cores cores..."
    make -j"$cores" CC=arm-linux-gnueabihf-gcc 2>&1 | tee build.log
    
    # 检查编译结果（更可靠的方法）
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
else
    if ! command -v arm-linux-gnueabi-gcc &> /dev/null; then
        sudo apt update
        sudo apt install -y gcc-arm-linux-gnueabi binutils-arm-linux-gnueabi
    fi
    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    # 配置和编译
    echo "Configuring..."
    ./configure \
    --host=arm-linux-gnueabi \
    --enable-static-link \
    --without-bash-malloc || error_exit "Configure failed"
    
    echo "Compiling with $cores cores..."
    make -j"$cores" CC=arm-linux-gnueabi-gcc 2>&1 | tee build.log
    
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
fi
}

build_bash_version_DR() {
    if ! command -v riscv64-linux-gnu-gcc &> /dev/null; then
        sudo apt update
        sudo apt install -y gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu
        sudo apt install -y autotools-dev
    fi
    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    # 配置和编译
    echo "Configuring..."
    ./configure \
    --host=riscv64-linux-gnu \
    --prefix=/usr/local || error_exit "Configure failed"
    
    echo "Compiling with $cores cores..."
    make -j"$cores" CC=riscv64-linux-gnu-gcc 2>&1 | tee build.log
    
    # 检查编译结果（更可靠的方法）
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
}

build_bash_version_SR() {
    if ! command -v riscv64-linux-gnu-gcc &> /dev/null; then
        sudo apt update
        sudo apt install -y gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu
        sudo apt install -y autotools-dev
    fi
    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    # 配置和编译
    echo "Configuring..."
    ./configure \
    --host=riscv64-linux-gnu \
    --enable-static-link \
    --without-bash-malloc || error_exit "Configure failed"
    
    echo "Compiling with $cores cores..."
    make -j"$cores" CC=riscv64-linux-gnu-gcc 2>&1 | tee build.log
    
    # 检查编译结果（更可靠的方法）
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
}

build_bash_version_DR3() {
    if ! command -v riscv32-unknown-linux-gnu-gcc &> /dev/null; then
        sudo apt update
        sudo apt install -y autoconf automake autotools-dev curl python3 libmpc-dev \
        libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf \
        libtool patchutils bc zlib1g-dev libexpat-dev ninja-build libglib2.0-dev
        install_risc-v32_gnu
    fi

    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    echo "Configuring..."
    if [[ "$version" == "5.3" ]]; then
        ./configure \
        --host=riscv32-unknown-linux-gnu \
        --prefix=/usr/local || error_exit "Configure failed"
    
        echo "Compiling with $cores cores..."
        make -j"$cores" CC="$HOME/riscv32/bin/riscv32-unknown-linux-gnu-gcc" 2>&1 | tee build.log
    else
        ./configure \
        --host=riscv32-unknown-linux-gnu \
        --prefix=/usr/local \
        CFLAGS="-Wno-error=old-style-definition -Wno-error=incompatible-pointer-types" || error_exit "Configure failed"
    
        echo "Compiling with $cores cores..."
        make -j"$cores" CC="$HOME/riscv32-gcc13/bin/riscv32-unknown-linux-gnu-gcc" 2>&1 | tee build.log
    fi
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
}

build_bash_version_SR3() {
    if ! command -v riscv32-unknown-linux-gnu-gcc &> /dev/null; then
        sudo apt update
        sudo apt install -y autoconf automake autotools-dev curl python3 libmpc-dev \
        libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf \
        libtool patchutils bc zlib1g-dev libexpat-dev ninja-build libglib2.0-dev
        install_risc-v32_gnu
    fi

    local version="$1"
    local tarball="bash-${version}.tar.gz"
    local url="https://ftp.gnu.org/gnu/bash/${tarball}"
    
    echo -e "${GREEN}Building Bash ${version}...${NC}"
    
    # 下载
    if [ -f "$tarball" ]; then
        echo "Using existing $tarball"
    else
        echo "Downloading ${url}..."
        wget "$url" || error_exit "Download failed"
    fi
    
    # 解压
    echo "Extracting..."
    tar -xzf "$tarball" || error_exit "Extraction failed"
    
    cd "bash-${version}" || error_exit "Cannot enter directory"
    
    # 获取编译核心数
    read -p "Enter number of cores for compilation [default: $(nproc)]: " cores
    cores=${cores:-$(nproc)}
    
    echo "Configuring..."
    if [[ "$version" == "5.3" ]]; then
        ./configure \
        --host=riscv32-unknown-linux-gnu \
        --enable-static-link \
        --without-bash-malloc \
        --prefix=/usr/local || error_exit "Configure failed"
    
        echo "Compiling with $cores cores..."
        make -j"$cores" CC="$HOME/riscv32/bin/riscv32-unknown-linux-gnu-gcc" 2>&1 | tee build.log
    else
        ./configure \
        --host=riscv32-unknown-linux-gnu \
        --prefix=/usr/local \
        --enable-static-link \
        --without-bash-malloc \
        CFLAGS="-Wno-error=old-style-definition -Wno-error=incompatible-pointer-types" || error_exit "Configure failed"
    
        echo "Compiling with $cores cores..."
        make -j"$cores" CC="$HOME/riscv32-gcc13/bin/riscv32-unknown-linux-gnu-gcc" 2>&1 | tee build.log
    fi
    if [ -f "bash" ] || [ -f "./bash" ]; then
        echo -e "${GREEN}Compilation successful!${NC}"
    else
        error_exit "Compilation failed. Check build.log"
    fi
    
    # 安装
    read -p "Install Bash ${version}? (Y/n) " answer
    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
        sudo make install
        echo -e "${GREEN}Bash ${version} installed successfully!${NC}"
        echo "Installed to: /usr/local/bin/bash"
        /usr/local/bin/bash --version
    else
        echo "Binary location: $(pwd)/bash"
        echo "You can install later with: sudo make install"
    fi
    
    cd ../..
}

echo -e "${GREEN}=== Bash Compilation Script ===${NC}"
echo "Welcome to bash installation script"
sleep 1
echo "Automated compilation and installation of bash from source code"
sleep 1

install_dependencies

BUILD_DIR=~/bashbuild
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR" || error_exit "Cannot create build directory"

echo -e "${GREEN}Working directory: ${BUILD_DIR}${NC}"

while true; do
    echo ""
    echo "Available versions: 5.0, 5.1, 5.2, 5.3"
    sleep 1
    read -p "Architecture (x86_64|ARM64/ARM32|i686/RISC-V64/32)?>>" arch
    read -p "Dynamic/Static? >> " build_type
    if [[ "$arch" == "x86_64" || "$arch" == "X86_64" ]]; then
        if [[ "$build_type" == "Dynamic" || "$build_type" == "dynamic" ]]; then
            read -p "Select version [default: 5.2]: " version
            version=${version:-5.2}
    
            case $version in
                5.0|5.1|5.2|5.3)
                    build_bash_version_DX "$version"
                    break
                    ;;
                *)
                    echo -e "${RED}Invalid version. Please choose 5.0, 5.1, 5.2, or 5.3${NC}"
                    ;;
                esac
            echo -e "${GREEN}✓ Script completed!${NC}"
        elif [[ "$build_type" == "Static" || "$build_type" == "static" ]]; then
            read -p "Select version [default: 5.2]: " version
    
            version=${version:-5.2}
    
            case $version in
                5.0|5.1|5.2|5.3)
                    build_bash_version_SX "$version"
                    break
                    ;;
                *)
                    echo -e "${RED}Invalid version. Please choose 5.0, 5.1, 5.2, or 5.3${NC}"
                    ;;
                esac
            echo -e "${GREEN}✓ Script completed!${NC}"
        else
            echo -e "${RED}Invalid input. Please enter 'Dynamic' or 'Static'.${NC}"
        fi 
    elif [[ "$arch" == "ARM64" || "$arch" == "arm64" ]]; then
        if [[ "$build_type" == "Dynamic" || "$build_type" == "dynamic" ]]; then
            read -p "Select version [default: 5.2]: " version
            version=${version:-5.2}
    
            case $version in
                5.0|5.1|5.2|5.3)
                    build_bash_version_DA "$version"
                    break
                    ;;
                *)
                    echo -e "${RED}Invalid version. Please choose 5.0, 5.1, 5.2, or 5.3${NC}"
                    ;;
                esac
            echo -e "${GREEN}✓ Script completed!${NC}"
        elif [[ "$build_type" == "Static" || "$build_type" == "static" ]]; then
            read -p "Select version [default: 5.2]: " version
    
            version=${version:-5.2}
    
            case $version in
                5.0|5.1|5.2|5.3)
                    build_bash_version_SA "$version"
                    break
                    ;;
                *)
                    echo -e "${RED}Invalid version. Please choose 5.0, 5.1, 5.2, or 5.3${NC}"
                    ;;
                esac
            echo -e "${GREEN}✓ Script completed!${NC}"
        else
            echo -e "${RED}Invalid input. Please enter 'Dynamic' or 'Static'.${NC}"
        fi 
    elif [[ "$arch" == "i686" || "$arch" == "I686" ]]; then
        if [[ "$build_type" == "Dynamic" || "$build_type" == "dynamic" ]]; then
            read -p "Select version [default: 5.2]: " version
            version=${version:-5.2}
    
            case $version in
                5.0|5.1|5.2|5.3)
                    build_bash_version_DI "$version"
                    break
                    ;;
                *)
                    echo -e "${RED}Invalid version. Please choose 5.0, 5.1, 5.2, or 5.3${NC}"
                    ;;
                esac
            echo -e "${GREEN}✓ Script completed!${NC}"
        elif [[ "$build_type" == "Static" || "$build_type" == "static" ]]; then
            read -p "Select version [default: 5.2]: " version
    
            version=${version:-5.2}
    
            case $version in
                5.0|5.1|5.2|5.3)
                    build_bash_version_SI "$version"
                    break
                    ;;
                *)
                    echo -e "${RED}Invalid version. Please choose 5.0, 5.1, 5.2, or 5.3${NC}"
                    ;;
                esac
            echo -e "${GREEN}✓ Script completed!${NC}"
        else
            echo -e "${RED}Invalid input. Please enter 'Dynamic' or 'Static'.${NC}"
        fi
    elif [[ "$arch" == "ARM32" || "$arch" == "arm32" ]]; then
        if [[ "$build_type" == "Dynamic" || "$build_type" == "dynamic" ]]; then
            read -p "Select version [default: 5.2]: " version
            version=${version:-5.2}
    
            case $version in
                5.0|5.1|5.2|5.3)
                    build_bash_version_DA3 "$version"
                    break
                    ;;
                *)
                    echo -e "${RED}Invalid version. Please choose 5.0, 5.1, 5.2, or 5.3${NC}"
                    ;;
                esac
            echo -e "${GREEN}✓ Script completed!${NC}"
        elif [[ "$build_type" == "Static" || "$build_type" == "static" ]]; then
            read -p "Select version [default: 5.2]: " version
    
            version=${version:-5.2}
    
            case $version in
                5.0|5.1|5.2|5.3)
                    build_bash_version_SA3 "$version"
                    break
                    ;;
                *)
                    echo -e "${RED}Invalid version. Please choose 5.0, 5.1, 5.2, or 5.3${NC}"
                    ;;
                esac
            echo -e "${GREEN}✓ Script completed!${NC}"
        else
            echo -e "${RED}Invalid input. Please enter 'Dynamic' or 'Static'.${NC}"
        fi
    elif [[ "$arch" == "RISC-V64" || "$arch" == "risc-v64" ]]; then
        if [[ "$build_type" == "Dynamic" || "$build_type" == "dynamic" ]]; then
            read -p "Select version [default: 5.2]: " version
            version=${version:-5.2}
    
            case $version in
                5.0|5.1|5.2|5.3)
                    build_bash_version_DR "$version"
                    break
                    ;;
                *)
                    echo -e "${RED}Invalid version. Please choose 5.0, 5.1, 5.2, or 5.3${NC}"
                    ;;
                esac
            echo -e "${GREEN}✓ Script completed!${NC}"
        elif [[ "$build_type" == "Static" || "$build_type" == "static" ]]; then
            read -p "Select version [default: 5.2]: " version
    
            version=${version:-5.2}
    
            case $version in
                5.0|5.1|5.2|5.3)
                    build_bash_version_SR "$version"
                    break
                    ;;
                *)
                    echo -e "${RED}Invalid version. Please choose 5.0, 5.1, 5.2, or 5.3${NC}"
                    ;;
                esac
            echo -e "${GREEN}✓ Script completed!${NC}"
        else
            echo -e "${RED}Invalid input. Please enter 'Dynamic' or 'Static'.${NC}"
        fi
    elif [[ "$arch" == "RISC-V32" || "$arch" == "risc-v32" ]]; then
        if [[ "$build_type" == "Dynamic" || "$build_type" == "dynamic" ]]; then
            read -p "Select version [default: 5.2]: " version
            version=${version:-5.2}
    
            case $version in
                5.0|5.1|5.2|5.3)
                    build_bash_version_DR3 "$version"
                    break
                    ;;
                *)
                    echo -e "${RED}Invalid version. Please choose 5.0, 5.1, 5.2, or 5.3${NC}"
                    ;;
                esac
            echo -e "${GREEN}✓ Script completed!${NC}"
        elif [[ "$build_type" == "Static" || "$build_type" == "static" ]]; then
            read -p "Select version [default: 5.2]: " version
    
            version=${version:-5.2}
    
            case $version in
                5.0|5.1|5.2|5.3)
                    build_bash_version_SR3 "$version"
                    break
                    ;;
                *)
                    echo -e "${RED}Invalid version. Please choose 5.0, 5.1, 5.2, or 5.3${NC}"
                    ;;
                esac
            echo -e "${GREEN}✓ Script completed!${NC}"
        else
            echo -e "${RED}Invalid input. Please enter 'Dynamic' or 'Static'.${NC}"
        fi
    else
        echo -e "${RED}Invalid architecture. Please enter x86_64, ARM64/ARM32, i686/RISC-V64, or RISC-V32.${NC}"
    fi
done