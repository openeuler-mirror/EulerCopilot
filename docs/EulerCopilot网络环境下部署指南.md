# EulerCopilot部署指南
## EulerCopilot介绍
EulerCopilot是一款智能问答工具，使用EulerCopilot可以解决操作系统知识获取的便捷性，并且为OS领域模型赋能开发者及运维人员。作为获取操作系统知识，使能操作系统生产力工具(如A-ops/Atune/X2openEuler/EulerMaker/EulerDevops/stratovirt/iSulad等)，颠覆传统命令交付方式，由传统命令交付方式向自然语义进化，并结合智能体任务规划能力，降低开发、使用操作系统特性的门槛。

### 组件介绍

| 组件                          | 端口            | 说明                  |
| ----------------------------- | --------------- | -------------------- |
| euler-copilot-framework       | 8002 (内部端口) | 智能体框架服务         |
| euler-copilot-web             | 8080            | 智能体前端界面        |
| euler-copilot-rag             | 8005 (内部端口) | 检索增强服务           |
| euler-copilot-vectorize-agent | 8001 (内部端口) | 文本向量化服务         |
| mysql                         | 3306 (内部端口) | MySQL数据库           |
| redis                         | 6379 (内部端口) | Redis数据库           |
| postgres                      | 5432 (内部端口) | 向量数据库             |
| secret_inject                 | 无              | 配置文件安全复制工具   |

## 环境要求
### 软件要求

| 类型        |  版本要求                         |  说明                                |
|------------| -------------------------------------|--------------------------------------|
| 操作系统    | openEuler 22.03 LTS及以上版本         | 无                                   |
| K3s        | >= v1.30.2，带有Traefik Ingress工具   | K3s提供轻量级的 Kubernetes集群，易于部署和管理 |
| Helm       | >= v3.15.3                           | Helm是一个 Kubernetes的包管理工具，其目的是快速安装、升级、卸载Eulercopilot服务 |
| python     | >=3.9.9                              | python3.9.9以上版本为模型的下载和安装提供运行环境 |
 
### 硬件要求
| 类型           |     硬件要求                  | 
|----------------| -----------------------------|
| 服务器         | 1台                           |
| CPU           | 鲲鹏或x86_64，>= 32 cores     |
| RAM           | >= 64GB                      |
| 存储          | >= 500 GB                    |
| GPU           | Tesla V100 16GB，4张         |
| NPU           | 910ProB、910B                |

注意： 
1. 若无GPU或NPU资源，建议通过调用openai接口的方式来实现功能。(接口样例：https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions) 参考链接[API-KEY的获取与配置](https://help.aliyun.com/zh/dashscope/developer-reference/acquisition-and-configuration-of-api-key?spm=a2c4g.11186623.0.0.30e7694eaaxxGa))
2. 调用第三方openai接口的方式不需要安装高版本的python(>=3.9.9)
3. 英伟达GPU对Docker的支持必需要新版本Docker（>= v25.4.0）

### 部署视图
![EulerCopilot部署图](./pictures/EulerCopilot部署视图.png)

## 获取EulerCopilot
- 从EulerCopilot的官方Git仓库[EulerCopilot](https://gitee.com/openeuler/EulerCopilot)下载最新的部署仓库
- 如果您正在使用Kubernetes，则不需要安装k3s工具。
```bash
# 下载目录以home为例
cd /home
git clone https://gitee.com/openeuler/EulerCopilot
```

## 环境准备
设备需联网并符合EulerCopilot的最低软硬件要求。确认服务器、硬件、驱动等准备就绪后，即可开始环境准备工作。为了顺利进行后续操作，请按照指引，先进入脚本部署目录`/home/EulerCopilot/euler-copilot-helm/scripts`，并且按照提供的操作步骤和脚本路径依次执行，以确保初始化成功。
|      序号    | 步骤内容     |    相关指令        |        说明    |
|-------------- |----------|---------------------------------------------|------------------------------------------ |
|1| 环境检查        | `bash check_env.sh`      | 主要对服务器的主机名、DNS、防火墙设置、磁盘剩余空间大小、网络、检查SELinux的设置  |
|2| 文件下载        | `bash download_file.sh`  | 模型bge-reranker-large、bge-mixed-mode 和分词工具text2vec-base-chinese-paraphrase的下载 |
|3| 安装部署工具    | `bash install_tools.sh v1.30.2+k3s1 v3.15.3 cn`  |  安装helm、k3s工具。注意：cn的使用是使用镜像站，可以去掉不用  |
|4| 大模型准备      | 提供第三方openai接口或基于硬件本都部署大模型   |   本地部署大模型可参考附录部分  |


## EulerCopilot安装

您的环境现已就绪，接下来即可启动EulerCopilot的安装流程。

###  1. 编辑配置文件
```bash
# 下载目录以home为例，进入EulerCopilot仓库的Helm配置文件目录
root@openeuler:~# cd /home/EulerCopilot
root@openeuler:/home/EulerCopilot# ll
total 28
drwxr-xr-x  3 root root 4096 Aug 28 17:45 docs/
drwxr-xr-x  5 root root 4096 Aug 28 17:45 euler-copilot-helm/

# 进入Helm配置文件目录
root@openeuler:/home/EulerCopilot# cd euler-copilot-helm/chart
root@openeuler:/home/EulerCopilot/euler-copilot-helm/chart# ll
total 28
-rw-r--r--  1 root root  135 Aug 28 17:45 Chart.yaml
drwxr-xr-x 10 root root 4096 Aug 28 17:55 templates/
-rw-r--r--  1 root root 6572 Aug 30 12:05 values.yaml

# 编辑values.yaml配置文件,请结合YAML中的注释部分进行修改
root@openeuler:/home/EulerCopilot/euler-copilot-helm/chart# vim values.yaml
# 注意事项：  
# - 修改domain为服务器的实际IP地址。  
# - 更新OpenAI的URL、Key、Model和Max Token为部署所需的值。  
# - 根据实际部署情况，更新vectorize、rag、framework中的BGE模型路径、文档向量化和分词工具路径。  

# - 如需在内网环境中修改Traefik配置以转发端口，请继续下一步。 
# 进入SSL配置目录，准备修改Traefik配置
root@openeuler:/home/EulerCopilot/euler-copilot-helm# cd chart_ssl/
root@openeuler:/home/EulerCopilot/euler-copilot-helm/chart_ssl# ll
total 20
-rw-r--r-- 1 root root  250 Aug 28 17:45 traefik-config.yml
-rw-r--r-- 1 root root  212 Aug 28 17:45 traefik-secret.yaml
-rw-r--r-- 1 root root  175 Aug 28 17:45 traefik-tlsstore.yaml
# 修改traefik-config.yml以转发HTTPS端口（如果需要）
root@openeuler:/home/EulerCopilot/euler-copilot-helm/chart_ssl/# vim traefik-config.yml
# 修改部分示例：  
# websecure:  
#   exposedPort: 8080  # 将此处的端口号修改为期望转发的HTTPS端口  

# 应用修改后的Traefik配置  
root@openeuler:/home/EulerCopilot/euler-copilot-helm/chart_ssl/# kubectl apply -f traefik-config.yml
```

###  2. 安装EulerCopilot
```bash
# 创建namespace
root@openeuler:~# cd /home/EulerCopilot/euler-copilot-helm/chart
root@openeuler:/home/EulerCopilot/euler-copilot-helm/chart# kubectl create namespace euler-copilot
# 设置环境变量
root@openeuler:/home/EulerCopilot/euler-copilot-helm/chart# export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
# 安装EulerCopilot
root@openeuler:/home/EulerCopilot/euler-copilot-helm/chart# helm install -n euler-copilot service .
```

###  3. 查看pod状态
```bash
# 镜像拉取过程可能需要大约一分钟的时间，请耐心等待。
# 部署成功后，所有Pod的状态应显示为Running。
root@openeuler:~# kubectl -n euler-copilot get pods
NAME                                          READY   STATUS    RESTARTS   AGE
framework-deploy-service-bb5b58678-jxzqr    2/2     Running   0          16d
mysql-deploy-service-c7857c7c9-wz9gn        1/1     Running   0          17d
pgsql-deploy-service-86b4dc4899-ppltc       1/1     Running   0          17d
rag-deploy-service-5b7887644c-sm58z         2/2     Running   0          110m
redis-deploy-service-f8866b56-kj9jz         1/1     Running   0          17d
vectorize-deploy-service-57f5f94ccf-sbhzp   2/2     Running   0          17d
web-deploy-service-74fbf7999f-r46rg         1/1     Running   0          2d

# 进入到postgres数据库，执行扩展命令
root@openeuler:~# kubectl -n euler-copilot exec -it pgsql-deploy-service-86b4dc4899-ppltc -- bash
root@pgsql-deploy-b4cc79794-qn8zd:/tmp# psql -U postgres -d postgres
psql (16.2 (Debian 16.2-1.pgdg120+2))
输入 "help" 来获取帮助信息.
postgres=# CREATE EXTENSION zhparser;
postgres=# CREATE EXTENSION vector;
postgres=# CREATE TEXT SEARCH CONFIGURATION zhparser (PARSER = zhparser);
postgres=# ALTER TEXT SEARCH CONFIGURATION zhparser ADD MAPPING FOR n,v,a,i,e,l WITH simple;
postgres=# exit
root@pgsql-deploy-b4cc79794-qn8zd:/tmp# exit
exit

# 注意：如果Pod状态出现失败，建议按照以下步骤进行排查
# 1.查看Kubernetes集群的事件(Events)，以获取更多关于Pod失败的上下文信息
root@openeuler:~# kubectl -n euler-copilot get events
# 2.查看镜像拉取是否成功
root@openeuler:~# k3s crictl images
# 3.检查EulerCopilot的 rag的Pod日志，以确定是否有错误信息或异常行为。
root@openeuler:~# kubectl logs rag-deploy-service-5b7887644c-sm58z -n euler-copilot
# 4.验证Kubernetes集群的资源状态，确保没有资源限制或配额问题导致Pod无法正常运行。
root@openeuler:~# df -h
# 5.如果未拉取成且镜像大小为0，请检查是否是k3s版本未满足要求，低于v1.30.2
root@openeuler:~# k3s -v
```
## 验证安装

访问EulerCopilot Web界面，请在浏览器中输入https://$(host_ip):8080（其中port默认值为8080，若更改则需相应调整）。

### 1. 创建登录账号密码
``` bash
# 首次登录触发mysql数据库生成user表
# 1.生成加密后的账号密码
root@openeuler:~# python3
Python 3.10.12 (main, Mar 22 2024, 16:50:05) [GCC 11.4.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import hashlib
>>> hashlib.sha256("[密码]".encode('utf-8')).hexdigest()
'f1db188c86b9f7cf154922a525891b807a6df8a44ad0fbace0cfe5840081a507'
# 保存生成加密后的密码
# 2.插入账号密码到mysql数据库
root@openeuler:~# kubectl -n euler-copilot exec -it mysql-deploy-service-c7857c7c9-wz9gn -- bash
bash-5.1# mysql -uroot -p8ZMTsY4@dgWZqoM6
# 密码在EulerCopilot/euler-copilot-helm/chart/values.yaml的mysql章节查看
mysql> use euler_copilot;
mysql> insert into user(user_sub, passwd) values ("[用户名]", "[加密后的密码]");
mysql> exit;
```
### 2. 问答验证

恭喜您，EulerCopilot的部署已完成！现在，您可以开启智能问答的非凡体验之旅了。

![EulerCopilot界面.png](./pictures/EulerCopilot界面.png)

## 构建专有领域智能问答
### 1. 构建openEuler专业知识领域的智能问答
  1. 修改values.yaml的pg的镜像仓为`pg-data`
  2. 修改values.yaml的rag部分的字段`knowledgebaseID: openEuler_2bb3029f`
  3. 将`vim EulerCopilot/euler-copilot-helm/chart/templates/pgsql/pgsql-deployment.yaml`的volume相关字段注释
  4. 进入`cd EulerCopilot/euler-copilot-helm/chart`，执行更新服务`helm upgrade -n euler-copilot service .`
  5. 进入网页端进行openEuler专业知识领域的问答
### 2. 构建项目专属知识领域智能问答
详细信息请参考文档 [EulerCopilot本地资产库构建指南.md](https://gitee.com/openeuler/EulerCopilot/blob/master/docs/EulerCopilot%E6%9C%AC%E5%9C%B0%E8%B5%84%E4%BA%A7%E5%BA%93%E6%9E%84%E5%BB%BA%E6%8C%87%E5%8D%97.md)

## 附录
### 大模型准备
#### GPU环境
参考以下方式进行部署
```bash
# 1.下载模型文件：
huggingface-cli download --resume-download Qwen/Qwen1.5-14B-Chat --local-dir Qwen1.5-14B-Chat
# 2.创建终端contol
screen -S contol
python3 -m fastchat.serve.controller
# 按ctrl A+D置于后台
# 3. 创建新终端 api
screen -S api
python3 -m fastchat.serve.openai_api_server --host 0.0.0.0 --port 30000  --api-keys sk-123456
# 按ctrl A+D置于后台
# 如果当前环境的python版本是3.12或者3.9可以创建python3.10的conda虚拟环境
mkdir -p /root/py310
conda create --prefix=/root/py310 python==3.10.14
conda activate /root/py310
# 4. 创建新终端worker
screen -S worker
screen -r worker
# 安装fastchat和vllm
pip install fschat vllm
# 安装依赖：
pip install fschat[model_worker]
python3 -m fastchat.serve.vllm_worker --model-path /root/models/Qwen1.5-14B-Chat/ --model-name qwen1.5 --num-gpus 8 --gpu-memory-utilization=0.7 --dtype=half
# 按ctrl A+D置于后台
# 5. 按照如下方式配置文件，并更新服务。
vim euler-copilot-helm/chart/values.yaml
修改如下部分
llm:
  # 开源大模型，OpenAI兼容接口
  openai:
    url: "http://$(IP):30000"
    key: "sk-123456"
    model: qwen1.5
    max_tokens: 8192
```
#### NPU环境
NPU环境部署可参考链接[MindIE安装指南](https://www.hiascend.com/document/detail/zh/mindie/10RC2/whatismindie/mindie_what_0001.html)


## FAQ
### 1. huggingface使用报错？
```bash
File "/usr/lib/python3.9/site-packages/urllib3/connection.py", line 186, in _new_conn
raise NewConnectionError(
urllib3.exceptions.eanconectionError: <urlib3.comnection.Hipscomnection object at exfblab6490>: Failed to establish a new conmection: [Errno 101] Network is unreachable
```
- 解决办法
```bash
pip3 install -U huggingface_hub
export HF_ENDPOINT=https://hf-mirror.com
```
### 2. 如何在rag容器中调用获取问答结果的接口？
```bash
# 请先进入到RAG pod
curl  -k -X POST "http://localhost:8005/kb/get_answer"  -H "Content-Type: application/json"  -d '{
      "question": "",
      "kb_sn": "default_test",
      "fetch_source": true  }'
```
### 3. 执行helm upgrade报错
```bash
Error: INSTALLATI0N FAILED: Kuberetes cluster unreachable: Get "http:/localhost:880/version": dial tcp [:1:8089: conect: conection refused
```
- 解决办法
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```
### 4. 无法查看pod的log？
```bash
[root@localhost euler-copilot]# kubectl logs rag-deployservice65c75c48d8-44vcp-n euler-copilotDefaulted container "rag" out of: rag.rag-copy secret (init)Error from server: Get "https://172.21.31.11:10250/containerlogs/euler copilot/rag deploy"service 65c75c48d8-44vcp/rag": Forbidden
```
- 解决办法
```bash
# 如果设置了代理，需要将本机的网络IP从代理中剔除
[root@localhost agent]#  cat /etc/systemd/system/k3s.service.env
http_proxy="http://172.21.60.51:3128"
https_proxy="http://172.21.60.51:3128"
no_proxy=172.21.31.10 # 代理中剔除本机IP
```
