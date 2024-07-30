#!/bin/bash
function help {
	echo -e "用法：./get_log.sh [命名空间] [日志时间]";
	echo -e "示例：./get_log.sh euler-copilot 1h";
}


function main {
	echo -e "[Info]开始收集各Pod日志";
	time=$(date -u +"%s");
	echo -e "[Info]当前命名空间：$1，当前时间戳：$time"
	filename="logs_$1_$time";
	mkdir $filename;
	echo $time > $filename/timestamp;

	echo "[Info]开始收集日志";
	kubectl -n $1 events > $filename/events.log;

	pod_names=$(kubectl -n $1 get pods -o name);
	while IFS= read -r line || [[ -n $line ]]; do
		mkdir -p $filename/$line;
		kubectl -n $1 describe $line > $filename/$line/details.log;
		kubectl -n $1 logs --previous --since $2 --all-containers=true --ignore-errors=true $line > $filename/$line/previous.log;
		kubectl -n $1 logs --since $2 --all-containers=true --ignore-errors=true $line > $filename/$line/current.log;
	done < <(printf '%s' "$pod_names");
	
	tar -czf $filename.tar.gz $filename/;
	rm -rf $filename;
	
	echo -e "[Info]收集日志结束，请将$filename.tar.gz提供给我们进行分析";
}


if [[ $# -lt 2 ]]; then
	help
else
	main $1 $2;
fi	
