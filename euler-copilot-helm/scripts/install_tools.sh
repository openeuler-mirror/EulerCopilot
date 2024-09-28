#/bin/bash

GITHUB_MIRROR="https://gh-proxy.com";
ARCH=$(uname -m);

# 函数：显示帮助信息
function help {
    echo -e "用法：bash install_tools.sh [K3s版本] [Helm版本] [cn: 是否使用镜像站]";
    echo -e "示例：bash install_tools.sh v1.30.2+k3s1 仅安装K3s";
    echo -e "      bash install_tools.sh v3.15.3 仅安装Helm";
    echo -e "      bash install_tools.sh v1.30.2+k3s1 v3.15.3 安装K3s和Helm";
}

function check_user {
    if [[ $(id -u) -ne 0 ]]; then
        echo -e "\033[31m[Error]请以root权限运行该脚本！\033[0m"
        exit 1;
    fi
}

function check_arch {
    case $ARCH in
        x86_64)
            ARCH=amd64
	    ;;
        aarch64)
            ARCH=arm64
	    ;;
        *)
            echo -e "\033[31m[Error]当前CPU架构不受支持\033[0m"
	    return 1;
	    ;;
    esac
    return 0
}

function check_helm {
    echo -e "[Info]测试与Helm官方网站之间的网络连通性"
    curl https://get.helm.sh --connect-timeout 5 -s > /dev/null
    if [[ $? -ne 0 ]]; then
        echo -e "\033[31m[Error]无法连接至get.helm.sh\033[0m"
	return 1
    fi
    return 0
}

function install_k3s {
    local image_name="k3s-airgap-images-$ARCH.tar.zst"
    
    if [[ $ARCH = "amd64" ]]; then
        local bin_name="k3s";
    elif [[ $ARCH = "arm64" ]]; then
        local bin_name="k3s-arm64";
    fi
    local k3s_bin_url="$GITHUB_MIRROR/https://github.com/k3s-io/k3s/releases/download/$k3s_version/${bin_name}"
    local k3s_image_url="$GITHUB_MIRROR/https://github.com/k3s-io/k3s/releases/download/$k3s_version/${image_name}"

    echo -e "[Info]下载K3s二进制文件"
    curl -L ${k3s_bin_url} -o /usr/local/bin/k3s
    if [[ $? -ne 0 ]]; then
        echo -e "\033[31m[Error]K3s二进制文件下载失败\033[0m"
        return 1;
    fi
    chmod +x /usr/local/bin/k3s

    echo -e "[Info]下载K3s依赖"
    mkdir -p /var/lib/rancher/k3s/agent/images
    curl -L ${k3s_image_url} -o /var/lib/rancher/k3s/agent/images/${image_name}
    if [[ $? -ne 0 ]]; then
        echo -e "\033[31m[Error]K3s依赖下载失败\033[0m"
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
    local url=""

    if [[ $use_mirror == "cn" ]]; then
        url="https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts/helm/v$helm_version/$file_name"
    else
        url="${use_mirror:+$GITHUB_MIRROR/}https://get.helm.sh/$file_name"
    fi

    echo -e "[Info]下载Helm"
    curl -L $url -o $file_name
    if [[ $? -ne 0 ]]; then
        echo -e "\033[31m[Error]Helm下载失败\033[0m";
        return 1;
    fi

    tar -zxvf $file_name --strip-components 1 -C /usr/local/bin linux-$ARCH/helm
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
            k3s_version=$arg
        elif [[ $arg =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            helm_version=$arg
        else
            echo "未知的参数: $arg"
            exit 1
        fi
    done
    # 检查 K3s 是否已安装
    if [[ -n $k3s_version ]]; then
        if command -v k3s &>/dev/null; then
            echo -e "[Info]K3s 已经安装，无需再次安装";
        else
            install_k3s "$k3s_version" "$use_mirror"
            if [[ $? -ne 0 ]]; then
                return 1;
            fi
        fi
    fi

    # 检查 Helm 是否已安装
    if [[ -n $helm_version ]]; then
        if command -v helm &>/dev/null; then
            echo -e "[Info]Helm 已经安装，无需再次安装";
        else
            check_helm
            if [[ $? -ne 0 ]]; then
                return 1;
            fi
            install_helm "$helm_version" "$use_mirror"
            if [[ $? -ne 0 ]]; then
                return 1;
            fi
        fi
    fi

    # 如果两个都需要安装，但至少有一个已安装，则不执行任何操作
    if [[ -n $k3s_version && -n $helm_version ]]; then
        if ! (command -v k3s &>/dev/null) || ! (command -v helm &>/dev/null); then
            echo -e "[Info]K3s 或 Helm 已经安装，无需再次安装";
            return 1;
        fi
    fi
}

main "$@"
