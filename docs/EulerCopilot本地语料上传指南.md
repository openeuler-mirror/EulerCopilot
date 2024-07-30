# 本地语料上传指南
本地语料上传指南是用户构建项目专有语料的指导，目前语料功能支持格式docx、txt、md格式
## 上传前准备
1. 修改配置文件中路径
修改euler-copilot-helm/chat/values.yaml的rag，指定待向量化的文档存放的位置：
`docs_dir: /home/data/corpus`
2. 将本地语料保存到服务器的`/home/data/corpus`目录
3. 执行环境变量,并更新服务：
```
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
helm upgrade -n euler-copilot 服务名称 .
```
4. 进入到rag容器：
`kubectl -n <namespace> exec -it <pod_id> -- bash`

## 上传语料到数据库
进入脚本目录进行语料相关操作`cd /rag-service/scripts`
- 初始化pg: 
`python3 corpus_manager.pyc --method init_pg --pg_host=127.0.0.1 --pg_port=5432 --pg_user=postgres --pg_pwd=123456`

- 初始化资产
`python3 corpus_manager.pyc --method init_corpus_asset `

- 上传语料：
`python3 corpus_manager.pyc --method up_corpus`

- 查询语料: 
`python3 corpus_manager.pyc --method query_corpus`

- 删除已上传的语料
`python3 corpus_manager.pyc --method del_corpus --corpus_name="文件名"`

- 清空数据库
`python3 corpus_manager.pyc --method clear_pg

## 端口转发
```
kubectl port-forward <pod_id> $(主机上的端口):$(容器端口) -n euler-copilot  --address=0.0.0.0
端口映射后可以直接用<主机IP:端口>去访问，例如如：http://192.168.16.177:3000/
```