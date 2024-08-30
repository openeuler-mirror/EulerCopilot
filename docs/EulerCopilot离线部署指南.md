# EulerCopilot离线部署指南
## EulerCopilot介绍
EulerCopilot是一款智能问答工具，使用EulerCopilot可以解决操作系统知识获取的便捷性，并且为OS领域模型赋能开发者及运维人员。作为获取操作系统知识，使能操作系统生产力工具(如A-ops/Atune/X2openEuler/Eulermake/EulerDevops/stratovirt/iSulad等)，颠覆传统命令交付方式，由传统命令交付方式向自然语义进化，并结合智能体任务规划能力，降低开发、使用操作系统特性的门槛。

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
| secret_ingect                 | 无              | 配置文件安全复制工具   |

## 环境要求
### 软件要求

| 类型        |  版本要求                         |  说明                                |
|------------| -------------------------------------|--------------------------------------|
| 操作系统    | openEuler 22.03 LTS及以上版本         | 无                                   |
| K3s        | >= v1.29.0，带有Traefik Ingress工具   | K3s提供轻量级的 Kubernetes集群，易于部署和管理 |
| Docker     | >= v25.4.0                           | Docker提供一个独立的运行应用程序环境    |
| Helm       | >= v3.14.4                           | Helm是一个 Kubernetes的包管理工具，其目的是快速安装、升级、卸载Eulercopilot服务 |
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
1. 若无GPU或NPU资源，建议通过调用openai接口的方式来实现功能。(接口样例：https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions)
2. 调用openai接口的方式不需要安装高版本的docker(>= v25.4.0)、python(>=3.9.9)

### 部署视图
![EulerCopilot部署图](./pictures/EulerCopilot部署视图.png)

## 获取EulerCopilot
- 从EulerCopilot的官方Git仓库[EulerCopilot](https://gitee.com/openeuler/EulerCopilot)下载最新的部署仓库
- 如果您正在使用Kubernetes，则不需要安装k3s工具。

## 环境准备
如果您的服务器、硬件、驱动等全部就绪，即可启动环境初始化流程，以下部署步骤在无公网环境执行。

### 1. 环境检查
环境检查主要是对服务器的主机名、DNS、防火墙设置、磁盘剩余空间大小、网络、检查SELinux的设置。
- 主机名设置
在Shell中运行如下命令：
  ```bash
  cat /etc/hostname
  echo "主机名" > /etc/hostname
  ```
- 系统DNS设置：需要给当前主机设置有效的DNS
- 防火墙设置
  ```bash
  # 查看防火墙状态
  systemctl status firewalld
  # 查看防火墙列表
  firewall-cmd --list-all
  # 关闭防火墙
  systemctl stop firewalld
  systemctl disable firewalld
  ```
- SELinux设置
  ```bash
  # 需要关闭selinux，可以临时关闭或永久关闭
  # 永久关闭SELinux
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
  # 临时关闭
  setenforce 0
  ```
### 2. 文件下载
- 模型文件下载
  - 需要下载模型文件bge-reranker-large、bge-mixed-model和分词工具text2vec-base-chinese-paraphrase
  - bge-mixed-model下载链接：[https://eulercopilot.obs.cn-east-3.myhuaweicloud.com/models/bge-mixed-model.rar]
  - bge-reranker-large下载链接: [https://eulercopilot.obs.cn-east-3.myhuaweicloud.com/models/bge-reranker-large.rar]
  - text2vec-base-chinese-paraphrase下载链接：[https://eulercopilot.obs.cn-east-3.myhuaweicloud.com/models/text2vec-base-chinese-paraphrase.rar]
- 镜像包下载
  - arm架构或x86架构的EulerCopilot服务的各组件镜像下载地址单独提供

### 3. 安装部署工具
#### 3.1 安装docker
如需要基于GPU/NPU部署大模型，需要检查docker版本是否满足>= v25.4.0 ，如不满足，请升级docker版本

#### 3.2 安装K3s并导入镜像
- 安装SELinux配置文件
  ```bash
  yum install -y container-selinux selinux-policy-base
  # packages里有k3s-selinux-0.1.1-rc1.el7.noarch.rpm的离线包
  rpm -i https://rpm.rancher.io/k3s-selinux-0.1.1-rc1.el7.noarch.rpm
  ```
- x86架构安装k3s
  ```bash
  # 在有网络的环境上获取k3s相关包，以v1.30.3+k3s1示例
  wget https://github.com/k3s-io/k3s/releases/download/v1.30.3%2Bk3s1/k3s
  wget https://github.com/k3s-io/k3s/releases/download/v1.30.3%2Bk3s1/k3s-airgap-images-amd64.tar.zst 
  cp k3s /usr/local/bin/
  cd /var/lib/rancher/k3s/agent
  mkdir images
  cp k3s-airgap-images-arm64.tar.zst /var/lib/rancher/k3s/agent/images
  # packages里有k3s-install.sh的离线包
  curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh 
  INSTALL_K3S_SKIP_DOWNLOAD=true ./k3s-install.sh
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  ```
- arm架构安装k3s
  ```bash
  # 在有网络的环境上获取k3s相关包，以v1.30.3+k3s1示例
  wget https://github.com/k3s-io/k3s/releases/download/v1.30.3%2Bk3s1/k3s-arm64
  wget https://github.com/k3s-io/k3s/releases/download/v1.30.3%2Bk3s1/k3s-airgap-images-arm64.tar.zst
  cp k3s-arm64 /usr/local/bin/k3s
  cd /var/lib/rancher/k3s/agent
  mkdir images
  cp k3s-airgap-images-arm64.tar.zst /var/lib/rancher/k3s/agent/images
  # packages里有k3s-install.sh的离线包
  curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh 
  INSTALL_K3S_SKIP_DOWNLOAD=true ./k3s-install.sh
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  ```
- 导入镜像
  ```bash
  # 导入已下载的镜像文件
  k3s ctr image import $(镜像文件)
  ```

#### 3.3 安装Helm工具
以当前的最新版本“3.15.0”、x86_64架构为例，运行如下命令：
  ```bash
  wget https://get.helm.sh/helm-v3.15.0-linux-amd64.tar.gz
  tar -xzf helm-v3.15.0-linux-amd64.tar.gz
  mv linux-amd64/helm /usr/sbin
  rm -rf linux-amd64
  ```
#### 3.4 大模型准备
提供openai接口或根据硬件型号进行大模型部署，GPU服务器可参考附录的相关指令进行部署，
NPU910B可参考[stable-diffusionxl模型-推理指导](https://gitee.com/ascend/ModelZoo-PyTorch/tree/master/ACL_PyTorch/）built-in/foundation_models/stable_diffusionxl)进行部署。

## EulerCopilot安装

您的环境现已就绪，接下来即可启动EulerCopilot的安装流程。

###  1. 编辑配置文件
```bash
# 进入EulerCopilot仓库目录，该目录包含文档目录和Helm安装配置文件目录
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

# 编辑values.yaml配置文件
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
root@openeuler:/home/EulerCopilot/euler-copilot-helm/chart_ssl/# cd ../chart
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
root@openeuler:~# kubectl -n euler-copilot get events
root@openeuler:~# kubectl logs rag-deploy-service-5b7887644c-sm58z -n euler-copilot 
# 注意事项：
# 如果Pod状态出现失败，建议按照以下步骤进行排查：
# 检查EulerCopilot的Pod日志，以确定是否有错误信息或异常行为。
# 验证Kubernetes集群的资源状态，确保没有资源限制或配额问题导致Pod无法正常运行。
# 查看相关的服务(Service)和部署(Deployment)配置，确保所有配置均正确无误。
# 如果问题依然存在，可以考虑查看Kubernetes集群的事件(Events)，以获取更多关于Pod失败的上下文信息。
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
>>> hashlib.sha256("密码".encode('utf-8')).hexdigest()
'f1db188c86b9f7cf154922a525891b807a6df8a44ad0fbace0cfe5840081a507'
# 保存生成加密后的密码
# 2.插入账号密码到mysql数据库
root@openeuler:~# kubectl -n euler-copilot exec -it mysql-deploy-service-c7857c7c9-wz9gn -- bash
bash-5.1# mysql -uroot -p8ZMTsY4@dgWZqoM6
# 密码在EulerCopilot/euler-copilot-helm/chart/values.yaml的myslq章节查看
mysql> use euler_copilot;
mysql> insert into user(user_sub, passwd) values ("用户名", "加密后的密码");
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
  4. 进入`cd EulerCopilot/euler-copilot-helm/chart`，执行更新服务`helm upgrade -n euler-copilot server .`
  5. 进入网页端进行openEuler专业知识领域的问答
### 2. 构建项目专属知识领域智能问答
详细信息请参考文档《EulerCopilot本地语料上传指南.md》

## 附录
### 大模型准备
#### GPU环境部署模型时，可参考以下推荐方式
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
#### NPU环境部署模型待补充
