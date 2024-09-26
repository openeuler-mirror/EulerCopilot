#!/bin/bash

GITHUB_MIRROR="https://gh-proxy.com";
ARCH=$(uname -m);

# 函数：显示帮助信息
function help {
    echo -e "用法：./install_tools.sh [K3s版本] [Helm版本] [cn: 是否使用镜像站]";
    echo -e "示例：./install_tools.sh v1.30.2+k3s1 仅安装K3s";
    echo -e "       ./install_tools.sh v3.15.3 仅安装Helm";
    echo -e "       ./install_tools.sh v1.30.2+k3s1 v3.15.3 安装K3s和Helm";
    echo -e "       ./install_tools.sh v1.30.2+k3s1 cn 使用中国镜像站安装K3s";
}

function check_user {
    if [[ $(id -u) -ne 0 ]]; then
        echo -e "\033[31m[Error]请以root权限运行该脚本！\033[0m";
        exit 1;
    fi
}

function check_arch {
    # 确保架构为x86_64或aarch64，并转换为amd64或arm64
    case $ARCH in
        x86_64)
            ARCH=amd64
            ;;
        aarch64)
            ARCH=arm64
            ;;
        *)
            echo -e "\033[31m[Error]当前CPU架构不受支持\033[0m";
            return 1;
            ;;
    esac

    return 0;
}

function install_k3s {
    local k3s_version=$1
    local use_mirror=$2
    local bin_name=k3s
    local image_name="k3s-airgap-images-$ARCH.tar.zst"
    local k3s_bin_url="${use_mirror:+$GITHUB_MIRROR/}https://github.com/k3s-io/k3s/releases/download/$k3s_version/${bin_name}"
    local k3s_image_url="${use_mirror:+$GITHUB_MIRROR/}https://github.com/k3s-io/k3s/releases/download/$k3s_version/${image_name}"
    
    echo -e "[Info]下载K3s二进制文件"
    curl -L ${k3s_bin_url} -o /usr/local/bin/k3s
    if [[ $? -ne 0 ]]; then
        echo -e "\033[31m[Error]K3s二进制文件下载失败\033[0m";
        return 1;
    fi

    chmod +x /usr/local/bin/k3s

    echo -e "[Info]下载K3s依赖"
    mkdir -p /var/lib/rancher/k3s/agent/images
    curl -L ${k3s_image_url} -o /var/lib/rancher/k3s/agent/images/${image_name}
    if [[ $? -ne 0 ]]; then
        echo -e "\033[31m[Error]K3s依赖下载失败\033[0m";
        return 1;
    fi

    echo -e "\033[32m[Success]K3s及其依赖下载成功\033[0m"

    bash -c "curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_SKIP_DOWNLOAD=true sh -"
    if [[ $? -ne 0 ]]; then
        echo -e "\033[31m[Error]K3s安装失败\033[0m";
        return 1;
    fi

    echo -e "\033[32m[Success]K3s安装成功\033[0m"
    return 0;

}

function install_helm {
    local helm_version=$1
    local use_mirror=$2
    local file_name="helm-$helm_version-linux-$ARCH.tar.gz"
    local url="${use_mirror:+$GITHUB_MIRROR/}https://get.helm.sh/$file_name"

    echo -e "[Info]下载Helm"
    curl -L $url -o $file_name
    if [[ $? -ne 0 ]]; then
        echo -e "\033[31m[Error]Helm下载失败\033[0m";
        return 1;
    fi

    tar -zxvf $file_name linux-$ARCH/helm --strip-components 1
    mv helm /usr/local/bin
    chmod +x /usr/local/bin/helm

    echo -e "\033[32m[Success]Helm安装成功\033[0m"
    return 0;
}

function main {
    if [[ $# -lt 1 || $# -gt 3 ]]; then
        help
        exit 1;
    fi

    check_user
    check_arch
    if [[ $? -ne 0 ]]; then
        exit 1;
    fi

    local k3s_version=""
    local helm_version=""
    local use_mirror=""

    for arg in "$@"; do
        if [[ $arg == v*+k3s1 ]]; then
            k3s_version=${arg%+k3s1}
        elif [[ $arg =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            helm_version=$arg
        elif [[ $arg == "cn" ]]; then
            use_mirror="cn"
        else
            echo "未知的参数: $arg"
            exit 1
        fi
    done

    if [[ -n $k3s_version ]]; then
        install_k3s "$k3s_version" "$use_mirror"
    fi

    if [[ -n $helm_version ]]; then
        install_helm "$helm_version" "$use_mirror"
    fi
}

main "$@"
