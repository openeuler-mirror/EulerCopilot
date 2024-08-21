# 本地语料上传指南
本地语料上传指南是用户构建项目专属语料的指导，当前支持docx、pdf、markdown和txt文件上传，推荐使用docx上传。
## 环境要求
|  环境要求   |  版本要求                           |  
|------------| ------------------------------------|
| CPU        | >= 8 cores                          |
| RAM        | >= 16 GB                            |
| Disk       | >= 100GB                            |
| Docker     | >= 24.0.0                           |

## 准备工作
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

## 上传语料
1. 进入脚本目录进行语料相关操作
`cd /rag-service/scripts`
2. 查看脚本帮助信息
```bash
[root@master scripts]# python3 corpus_manager.py --help
usage: corpus_manager.py [-h] --method
                         {init_pg_info,init_rag_info,init_pg,init_corpus_asset,clear_pg,up_corpus,de                                              l_corpus,query_corpus,stop_embdding_jobs}
                         [--pg_host PG_HOST] [--pg_port PG_PORT] [--pg_user PG_USER]
                         [--pg_pwd PG_PWD] [--rag_host RAG_HOST] [--rag_port RAG_PORT]
                         [--kb_name KB_NAME] [--kb_asset_name KB_ASSET_NAME]
                         [--corpus_dir CORPUS_DIR] [--corpus_chunk CORPUS_CHUNK]
                         [--corpus_name CORPUS_NAME] [--up_chunk UP_CHUNK]
                         [--ssl_enable SSL_ENABLE]
                         [--embedding_model {TEXT2VEC_BASE_CHINESE_PARAPHRASE,BGE_LARGE_ZH,BGE_MIXED                                              _MODEL}]

optional arguments:
  -h, --help            show this help message and exit
  --method {init_pg_info,init_rag_info,init_pg,init_corpus_asset,clear_pg,up_corpus,del_corpus,query                                              _corpus,stop_embdding_jobs}
                        脚本使用模式，有初始化数据库配置、初始化数据库、初始化语料资产、
                        清除数据库所有内容、上传语料(当前支持txt、html、pdf、docx和md格式)、删除语料                                              、查询语 料和停止当前上传任务
  --pg_host PG_HOST     语料库所在postres的ip
  --pg_port PG_PORT     语料库所在postres的端口
  --pg_user PG_USER     语料库所在postres的用户
  --pg_pwd PG_PWD       语料库所在postres的密码
  --rag_host RAG_HOST   rag服务的ip
  --rag_port RAG_PORT   rag服务的port
  --kb_name KB_NAME     资产名称
  --kb_asset_name KB_ASSET_NAME
                        资产库名称
  --corpus_dir CORPUS_DIR
                        待上传语料所在路径
  --corpus_chunk CORPUS_CHUNK
                        语料切割尺寸
  --corpus_name CORPUS_NAME
                        待查询或者待删除语料名
  --up_chunk UP_CHUNK   语料单次上传个数
  --ssl_enable SSL_ENABLE
                        rag是否为https模式启动
  --embedding_model {TEXT2VEC_BASE_CHINESE_PARAPHRASE,BGE_LARGE_ZH,BGE_MIXED_MODEL}
                        初始化资产时决定使用的嵌入模型
```
3. 相关命令如下所示：
- 初始化pg配置信息
`python3 corpus_manager.pyc --method init_pg_info --pg_host=pgsql-db-$(服务名).euler-copilot.svc.cluster.local --pg_port=5432 --pg_user=postgres --pg_pwd=123456`
- 初始化pg
`python3 corpus_manager.pyc -method init_pg`
- 初始化资产
`python3 corpus_manager.pyc --method init_corpus_asset`
- 语料上传
`python3 corpus_manager.pyc --method up_corpus --up_chunk UP_CHUNK  $(语料单次上传个数)`  
注意：语料单次上传个数默认是100，推荐单次上传200-300个
- 查询语料 
`python3 corpus_manager.pyc --method query_corpus`
- 删除已上传的语料
`python3 corpus_manager.pyc --method del_corpus --corpus_name="文件名"`
- 清空数据库
`python3 corpus_manager.pyc --method clear_pg`
- 停止语料上传
`python3 corpus_manager.pyc --method stop_embdding_jobs`
注意：如果上传过程上时间无响应，可使用该命令停止上传`
- 语料上传失败
进入postgres数据库执行`update vectorization_job set status = 'FAILURE' where id in (select id from vectorization_job where status != 'SUCCESS' and status != 'FAILURE');`
接着进入rag的pod执行`rm -rf /tmp/vector_data`

## 网页端查看语料上传
您可以根据需要进行端口转发，并在网页端查看语料上传详情。
```bash
kubectl port-forward <pod_id> $(主机上的端口):$(容器端口) -n euler-copilot  --address=0.0.0.0
```
端口映射后可以直接用<主机IP:端口>去访问，例如`http://192.168.16.178:3000/`
