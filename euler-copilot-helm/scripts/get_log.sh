#!/bin/bash
NAMESPACE="";

function help {
	echo -e "用法：./get_log.sh [命名空间]";
	echo -e "示例：./get_log.sh euler-copilot";
}


function main {
	echo -e "[Info]开始收集各Pod日志";
	time=$(date -u +"%s");
	echo -e "[Info]当前命名空间：$NAMESPACE，当前时间戳：$time"
	
	
}


if [[ $# -lt 1 ]]; then
	help
else
	main $1;
fi
		