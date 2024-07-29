#!/bin/bash
function check_user {
    if [[ $(id -u) -ne 0 ]]; then
        echo -e "\033[31m[Error]请以root权限运行该脚本！\033[0m";
        return 1;
    fi

    return 0;
}

function check_version {
    current_version_id="$1";
    supported_version=("$@");

    echo -e "[Info]当前操作系统版本为：$current_version_id";
    for version_id in "${supported_version[@]:1}"
    do
        if [[ $current_version_id =~ $version_id ]]; then
            echo -e "\033[32m[Success]操作系统满足兼容性要求\033[0m";
            return 0;
        fi
    done;

    echo -e "\033[31m[Error]操作系统不满足兼容性要求，脚本将退出\033[0m";
    return 1;
}

function check_os_version {
    id=$(grep -E "^ID=" /etc/os-release | cut -d '"' -f 2);
    version=$(grep -E "^VERSION_ID=" /etc/os-release | cut -d '"' -f 2);

    echo -e "[Info]当前发行版为：$id";
    if [[ $id =~ "openEuler" ]] || [[ $id =~ "bclinux" ]]; then
        supported_version=(
            "22.03"
            "22.09"
            "23.03"
            "23.09"
            "24.03"
        )
        check_version $version "${supported_version[@]}";
        return $?;
    fi

    if [[ $id =~ "InLinux" ]]; then
        supported_version=(
            "23.12"
        )
        check_version $version "${supported_version[@]}";
        return $?;
    fi
    
    if [[ $id =~ "FusionOS" ]]; then
        supported_version=(
            "23"
        )
        check_version $version "${supported_version[@]}";
        return $?;
    fi
    
    echo -e "\033[31m[Error]发行版不受支持，脚本将退出\033[0m";
    return 1;
}

function check_hostname {
    current_hostname=$(cat /etc/hostname);
    if [[ -z "$current_hostname" ]];
    then
        echo -e "\033[31m[Error]当前操作系统未设置主机名，将进行主机名设置\033[0m";
        read -p "主机名：" new_hostname;
        set_hostname $new_hostname;
        return $?;
    else
        echo -e "[Info]当前主机名为：$current_hostname";
        echo -e "\033[32m[Success]当前操作系统主机名已设置\033[0m";
        return 0;
    fi
}

function set_hostname {
    echo -e "[Info]检查hostnamectl";
    if ! [[ -x "$(command -v hostnamectl)" ]]; then
        echo -e "\033[31m[Error]hostnamectl程序不存在，主机名设置可能不会持久生效\033[0m";
        echo $1 > /etc/hostname;
        echo -e "\033[32m[Success]手动设置主机名成功\033[0m";
        return 0;
    fi

    echo -e "[Info]使用hostnamectl设置主机名";
    hostnamectl set-hostname $1;
    echo -e "\033[32m[Success]手动设置主机名成功\033[0m";
    return 0;
}

function check_dns {
    echo -e "[Info]检查DNS服务器设置";
    nameserver_line=$(cat /etc/resolv.conf | grep nameserver | wc -l);
    if [[ $nameserver_line -ne 0 ]]; then
        echo -e "\033[32m[Success]DNS服务器已配置\033[0m";
        return 0;
    fi

    echo -e "\033[31m[Error]DNS服务器未配置\033[0m";
    read -p "请输入新的" new_dns;
    set_dns $new_dns;
    return $?;
}

function set_dns {
    echo -e "[Info]检查NetworkManager";
    if [[ $(systemctl status NetworkManager | grep running) -ne 0 ]]; then
        echo -e "\033[31m[Error]NetworkManager未启用，将直接编辑resolv.conf\033[0m";
        cp -f /etc/resolv.conf /etc/resolv.bak;
        echo "nameserver $1" > /etc/resolv.conf;
        echo -e "\033[32m[Success]手动设置DNS服务器成功\033[0m";
        return 0;
    fi

    echo -e "[Info]NetworkManager已启用，使用nmcli进行DNS服务器配置";
    echo -e "[Info]将手动设置DNS地址，DNS地址将应用于第一块活跃网卡中";
    net_ic=$(nmcli -t -f NAME c show --active | head -1)
    if [[ -z "$net_ic" ]]; then
        echo -e "\033[31m[Error]NetworkManager无法检测到网卡，请确认网卡是否启用\033[0m";
        return 1;
    fi
    nmcli con mod $net_ic ipv4.ignore-auto-dns yes;
    nmcli con mod $net_ic ipv4.dns "$1";
    if [[ $? -ne 0 ]]; then
        echo -e "\033[31m[Error]使用NetworkManager设置DNS失败";
        return 1;
    fi
    return 0;
}

function check_ram {
    echo -e "[Info]检查RAM容量";
    RAM_THRESHOLD=16000;

    current_mem=$(free --mega | grep "Mem" | awk '{print $2}')
    echo -e "[Info]当前机器的RAM为：$current_mem MB";
    if [[ $(expr $current_mem) -lt $RAM_THRESHOLD ]]; then
        echo -e "\033[31m[Error]当前机器总RAM小于 $RAM_THRESHOLD MB\033[0m";
        return 1;
    fi
    echo -e "[Info]当前机器RAM符合要求";
    return 0;
}

function check_disk {
    echo -e "[Info]检查磁盘剩余空间";
    current_disk_info=$(df -BM --output=avail,size /var/lib | awk 'NR==2{print $0}')
    current_disk_avaliable=$(echo $current_disk_info | awk '{print $1}' | grep -e "[0-9]*" -m 1 -o)
    current_disk_size=$(echo $current_disk_info | awk '{print $2}' | grep -e "[0-9]*" -m 1 -o)

    PERCENT_THRESHOLD=0.85;
    DISK_THRESHOLD=50000;

    if [[ $(expr $current_disk_avaliable) -lt $DISK_THRESHOLD ]]; then
        echo -e "\033[31m[Error]当前机器磁盘空间小于 $DISK_THRESHOLD MB\033[0m";
        return 1;
    fi

    current_percent=$(echo 1 - \($current_disk_avaliable - $DISK_THRESHOLD\) / $current_disk_size | bc -l);
    if [[ $(echo "$current_percent > $PERCENT_THRESHOLD" | bc) -eq 1 ]]; then
        echo -e "\033[31m[Error]当前机器在部署后磁盘占用率将大于 $(echo $PERCENT_THRESHOLD*100 | bc) %\033[0m";
        return 1;
    fi

    echo -e "[Info]当前机器磁盘空间满足要求";
    return 0;
}

function check_network {
    echo -e "[Info]正在检查当前机器网络情况";
    if [[ -x $(command -v curl) ]]; then
        echo -e "\033[31m[Error]Curl不存在，将进行安装\033[0m";
        yum install -y curl;
        if [[ $? -ne 0 ]]; then
            echo -e "\033[31m[Error]Curl安装失败\033[0m";
            return 1;
        fi
    fi

    curl https://swr.cn-southwest-2.myhuaweicloud.com --connect-timeout 5 -s > /dev/null;
    if [[ $? -ne 0 ]]; then
        echo -e "\033[31m[Error]当前机器网络无法连接至镜像仓库，请检查网络配置，或使用离线部署方案\033[0m";
        return 1;
    fi
    return 0;
}

function check_selinux {
    echo -e "[Info]检查SELinux情况";
    status=$(cat /etc/selinux/config | grep -e "^SELINUX=.*$" | cut -d "=" -f 2);
    if [[ $status =~ "enforcing" ]]; then
        echo -e "\033[31m[Error]SELinux已开启，可能会导致服务运行错误\033[0m";
        read -p "关闭SELinux？(Y/n)" choice;
        case $choice in 
            [yY]) sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config;
                   setenforce 0;
                   if [[ $? -ne 0 ]]; then
                       echo -e "\033[31m[Error]自动关闭SELinux失败，请手动关闭后重试\033[0m";
                       return 1;
                   fi
                   return 0;
                   ;;

            *) echo -e "\033[31m[Error]已终止执行，请手动关闭SELinux后重试\033[0m";
                   return 1;
                   ;;
        esac
    fi
    
    echo -e "[Info]未开启SELinux";
    return 0;
}

function check_firewall {
	echo -e "[Info]检查防火墙情况";
	status=$(systemctl status firewalld | grep inactive);
	if [[ $? -ne 0 ]]; then
		echo -e "\033[31m[Error]FirewallD防火墙正在运行中\033[0m";
		read -p "关闭FirewallD？(Y/n)" choice;
		
		case $choice in
			[yY]) systemctl stop firewalld;
			       systemctl disable firewalld;
			       if [[ $? -ne 0 ]]; then
				       echo -e "\033[31m[Error]FirewallD防火墙自动关闭失败，请手动关闭防火墙后重试\033[0m";
				       return 1;
				   fi
				   echo -e "\033[32m[Success]FirewallD防火墙关闭成功\033[0m";
				   return 0;
                   ;;
			*) echo -e "\033[31m[Error]已终止执行，请手动关闭FirewallD防火墙后重试\033[0m";
			    return 1;
                ;;
		esac
	fi
	
	echo -e "[Info]未安装防火墙FirewallD";
	return 0;
}


function main {
    check_user
    if [[ $? -ne 0 ]]; then
        return 1;
    fi

    check_os_version
    if [[ $? -ne 0 ]]; then
        return 1;
    fi

    check_hostname
    if [[ $? -ne 0 ]]; then
        return 1;
    fi

    check_dns
    if [[ $? -ne 0 ]]; then
        return 1;
    fi

    check_ram
    if [[ $? -ne 0 ]]; then
        return 1;
    fi

    check_disk
    if [[ $? -ne 0 ]]; then
        return 1;
    fi

    check_network
    if [[ $? -ne 0 ]]; then
        return 1;
    fi
    
    check_selinux
	if [[ $? -ne 0 ]]; then
		return 1;
	fi
	
	check_firewall
	if [[ $? -ne 0 ]]; then
		return 1;
	fi

    echo -e "\033[32m[Success]部署环境检查通过\033[0m";
    return 0;
}


main