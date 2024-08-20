#!/bin/bash
GITHUB_MIRROR="https://gh-proxy.com";
ARCH=$(uname -m);


function help {
	echo -e "用法：./install_tools.sh [K3s版本] [Helm版本] [cn: 是否使用镜像站]";
	echo -e "示例：./install_tools.sh \"v1.30.2+k3s1\" \"v3.15.3\"";
}

function check_user {
    if [[ $(id -u) -ne 0 ]]; then
        echo -e "\033[31m[Error]请以root权限运行该脚本！\033[0m";
        return 1;
    fi

    return 0;
}

function check_arch {
	if [[ $ARCH != "x86_64" ]] && [[ $ARCH != "aarch64" ]]; then
		echo -e "\033[31m[Error]当前CPU架构不受支持\033[0m";
		return 1;
	fi
	
	if [[ $ARCH = "x86_64" ]]; then
		ARCH="amd64";
	elif [[ $ARCH = "aarch64" ]]; then
		ARCH="arm64";
	fi
	
	return 0;
}

function check_existing {
	if [[ -x $(command -v k3s) ]] && [[ -x $(command -v helm) ]]; then
		echo -e "[Info]K3s与Helm已经安装，无需再次安装";
		return 1;
	fi
	
	return 0;
}

function check_github {
	if [[ $1 = "cn" ]]; then
	    echo -e "[Info]测试与GitHub镜像站之间的网络连通性";
	    curl $GITHUB_MIRROR --connect-timeout 5 -s > /dev/null;
	    if [[ $? -ne 0 ]]; then
			echo -e "\033[31m[Error]无法连接至GitHub镜像站\033[0m";
		else
			return 0;
		fi
	fi
	
	echo -e "[Info]测试与GitHub之间的网络连通性";
	curl https://github.com --connect-timeout 5 -s > /dev/null;
	if [[ $? -ne 0 ]]; then
		echo -e "\033[31m[Error]无法连接至GitHub\033[0m";
		return 1;
	fi
	
	return 0;
}

function check_helm {
	echo -e "[Info]测试与Helm官方网站之间的网络连通性";
	curl https://get.helm.sh --connect-timeout 5 -s > /dev/null;
	if [[ $? -ne 0 ]]; then
		echo -e "\033[31m[Error]无法连接至get.helm.sh\033[0m";
		return 1;
	fi
	return 0;
}

function download_k3s {
	if [[ $ARCH = "amd64" ]]; then
		bin_name="k3s";
	elif [[ $ARCH = "arm64" ]]; then
		bin_name="k3s-arm64";
	fi
	
	image_name="k3s-airgap-images-$ARCH.tar.zst";
	
	if [[ $1 = "cn" ]]; then
		bin_url="$GITHUB_MIRROR/https://github.com/k3s-io/k3s/releases/download/$2/$bin_name";
		image_url="$GITHUB_MIRROR/https://github.com/k3s-io/k3s/releases/download/$2/$image_name";
	else
		bin_url="https://github.com/k3s-io/k3s/releases/download/$1/$bin_name";
		image_url="https://github.com/k3s-io/k3s/releases/download/$1/$image_name";
	fi
	
	echo -e "[Info]下载K3s";
	curl $bin_url -o k3s -L;
	if [[ $? -ne 0 ]]; then
		echo -e "\033[31m[Error]K3s下载失败\033[0m";
		return 1;
	fi
	
	mv k3s /usr/local/bin;
	chmod +x /usr/local/bin/k3s;
	
	echo -e "[Info]下载K3s依赖";
	curl $image_url -o $image_name -L;
	if [[ $? -ne 0 ]]; then
		echo -e "\033[31m[Error]K3s依赖下载失败\033[0m";
		return 1;
	fi
	
	mkdir -p /var/lib/rancher/k3s/agent/images;
	mv $image_name /var/lib/rancher/k3s/agent/images/;
	
	echo -e "\033[32m[Success]K3s及其依赖下载成功\033[0m";
	
	mkdir -p /etc/rancher/k3s;
	echo -e "[Info]请输入Docker私仓登录信息：";
	read -p "私仓地址：" repo_url;
	read -p "用户名：" repo_user;
	read -p "密码：" repo_pass;
	cat > /etc/rancher/k3s/registries.yaml <<-EOF
	mirrors:
	  "docker.io":
	    endpoint:
	      - "https://docker.anyhub.us.kg"
	      - "https://docker.1panel.live"
	      - "https://dockerhub.icu"
	      - "https://docker.ckyl.me"
	      - "https://docker.awsl9527.cn"
	      - "https://dhub.kubesre.xyz"
	configs:
	  "$repo_url":
	    auth:
	      username: $repo_user
	      password: $repo_pass
	EOF
	
	bash -c "curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_SKIP_DOWNLOAD=true sh -";
	if [[ $? -ne 0 ]]; then
		echo -e "\033[31m[Error]K3s安装失败\033[0m";
		return 1;
	fi
	echo -e "\033[32m[Success]K3s安装成功\033[0m";
	
	return 0;
}


function download_helm {
	file_name="helm-$1-linux-$ARCH.tar.gz";
	url="https://get.helm.sh/$file_name";
	
	curl $url -o $file_name -L;
	if [[ $? -ne 0 ]]; then
		echo -e "\033[31m[Error]Helm下载失败\033[0m";
		return 1;
	fi
	
	tar -zxvf $file_name linux-$ARCH/helm --strip-components 1;
	mv helm /usr/local/bin;
	chmod +x /usr/local/bin/helm;
	
	echo -e "\033[32m[Success]Helm安装成功\033[0m";
	return 0;
}

function main {
    echo -e "[Info]安装K3s与Helm";
    
    check_user
    if [[ $? -ne 0 ]]; then
		return 1;
	fi
	
	check_existing
	if [[ $? -ne 0 ]]; then
		return 1;
	fi
	
	check_arch
	if [[ $? -ne 0 ]]; then
		return 1;
	fi
	
	check_github $3
	if [[ $? -ne 0 ]]; then
		return 1;
	fi
	
	check_helm
	if [[ $? -ne 0 ]]; then
		return 1;
	fi
	
	download_k3s $3 $1
	if [[ $? -ne 0 ]]; then
		return 1;
	fi
	
	download_helm $2
	if [[ $? -ne 0 ]]; then
		return 1;
	fi
	
	return 0;
}

if [[ $# -lt 2 ]]; then
	help
else
	main $1 $2 $3;
fi
