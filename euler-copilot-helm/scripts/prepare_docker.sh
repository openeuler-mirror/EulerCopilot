#!/bin/bash

function stop_docker {
	echo -e "[Info]检查是否已安装Docker";
	if ! [[ -x $(command -v docker) ]]; then
		echo -e "[Info]未安装Docker";
		return 0;
	fi

	echo -e "\033[33m[Warning]即将停止Docker服务，确定继续吗？\033[0m";
        read -p "(Y/n): " choice;
    case $choice in
            [Yy])
                systemctl stop docker
                if [[ $? -ne 0 ]]; then
                    echo -e "\033[31m[Error]停止Docker服务错误，中止运行\033[0m"
                    return 1
                else
                    echo -e "\033[32m[Success]停止Docker服务成功\033[0m"
                fi
                ;;
            [Nn])
                echo -e "\033[31m[Error]操作取消\033[0m"
                return 1
                ;;
            *)
                echo -e "\033[31m[Error]无效输入，操作取消\033[0m"
                return 1
                ;;
    esac

	echo -e "\033[33m[Warning]即将尝试卸载旧版本Docker，确定继续吗？\033[0m";
	read -p "(Y/n): " choice2;
    case $choice2 in
            [Yy])
                yum remove -y docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
                if [[ $? -ne 0 ]]; then
                    echo -e "\033[31m[Error]Docker旧版本卸载失败\033[0m"
                    return 1
                else
                    echo -e "\033[32m[Success]Docker旧版本已卸载\033[0m"
                fi
                ;;
            [Nn])
                echo -e "\033[31m[Error]操作取消\033[0m"
                return 1
                ;;
             *)
                echo -e "\033[31m[Error]无效输入，操作取消\033[0m"
                return 1
                ;;
    esac
	return 0;
}

function setup_docker_repo {
    echo -e "[Info]设置Docker RPM Repo";
    basearch=$(arch)
    cat > /etc/yum.repos.d/docker-ce.repo <<-EOF
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/centos/9/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/centos/gpg
EOF
    echo -e "[Info]更新yum软件包列表";
    yum makecache
    if [[ $? -ne 0 ]]; then
        echo -e "\033[31m[Error]更新yum软件包列表失败\033[0m";
        return 1;
    else
        echo -e "\033[32m[Success]yum软件包列表更新成功\033[0m";
    fi
    return 0;
}

function install_docker {
	echo -e "[Info]安装Docker";
	yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin;
	if [[ $? -ne 0 ]]; then
		echo -e "\033[31m[Error]安装Docker失败\033[0m";
		return 1;
	else
		echo -e "\033[32m[Success]安装Docker成功\033[0m";
	fi
	systemctl enable docker;
	
	echo -e "[Info]设置DockerHub镜像";
	if ! [[ -d "/etc/docker" ]]; then
		mkdir /etc/docker;
	fi
	
	if [[ -f "/etc/docker/daemon.json" ]]; then
		echo -e "\033[31m[Error]daemon.json已存在，请手动配置DockerHub镜像\033[0m";
	else
		cat > /etc/docker/daemon.json <<-EOF
{
    	"registry-mirrors": [
        	"https://docker.anyhub.us.kg",
        	"https://docker.1panel.live",
        	"https://dockerhub.icu",
        	"https://docker.ckyl.me",
        	"https://docker.awsl9527.cn",
        	"https://dhub.kubesre.xyz",
            "https://gg3gwnry.mirror.aliyuncs.com"
    	]
}
EOF
	fi
	systemctl restart docker;
	if [[ $? -ne 0 ]]; then
		echo -e "\033[31m[Error]Docker启动失败\033[0m";
		return 1;
	else
		echo -e "\033[32m[Success]Docker启动成功\033[0m";
		return 0;
	fi
}

function login_docker {
	echo -e "[Info]登录Docker私仓";
	read -p "仓库地址：" url;
	read -p "用户名：" username;
	read -p "密码：" password;
	
	docker login -u $username -p $password $url;
	if [[ $? -ne 0 ]]; then
		echo -e "\033[31m[Error]Docker登录失败\033[0m";
		return 1;
	else
		echo -e "\033[32m[Success]Docker登录成功\033[0m";
		return 0;
	fi
}

function main {
	echo -e "[Info]正在更新Docker";
	
	stop_docker;
	if [[ $? -ne 0 ]]; then
		return 1;
	fi
	
	setup_docker_repo;
	if [[ $? -ne 0 ]]; then
		return 1;
	fi
	
	install_docker;
	if [[ $? -ne 0 ]]; then
		return 1;
	fi
	
	login_docker;
	if [[ $? -ne 0 ]]; then
		return 1;
	fi
	
	return 0;
}

main
