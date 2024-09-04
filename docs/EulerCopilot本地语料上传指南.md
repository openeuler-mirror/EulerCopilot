# 本地语料上传指南
- RAG是一个检索增强的模块，该指南主要是为rag提供命令行的方式进行资产管理、资产库管理和语料资产管理；
  对于资产管理提供了资产创建、资产查询和资产删除等功能；
  对于资产库管理提供了资产库创建、资产库查询和资产库删除等功能；
  对于语料资产管理提供了语料上传、语料查询和语料删除等功能，且语料资产管理的语料上传部分依赖语料预处理功能；
  对于语料预处理功能提供了文档内容解析、文档格式转换和文档切功能。

- rag当前仅面向管理员进行资产管理，对于管理员而言，可以拥有多个资产，一个资产包含多个资产库（不同资产库的使用的向量化模型可能不同），一个资产库对应一个语料资产。

- 本地语料上传指南是用户构建项目专属语料的指导，当前支持docx、pdf、markdown和txt文件上传，推荐使用docx上传。

## 准备工作
1. 将本地语料保存到服务器的待向量化目录（例如将所有文档放至默认路径`/home/data/corpus`）
2. 更新EulerCopilot服务：
```bash
root@openeuler:/home/EulerCopilot/euler-copilot-helm/chart# helm upgrade -n euler-copilot service .
# 请注意：service是服务名，可根据实际修改
```
3. 进入到rag容器：
```bash
root@openeuler:~# kubectl -n euler-copilot get pods
NAME                                          READY   STATUS    RESTARTS   AGE
framework-deploy-service-bb5b58678-jxzqr    2/2     Running   0          16d
mysql-deploy-service-c7857c7c9-wz9gn        1/1     Running   0          17d
pgsql-deploy-service-86b4dc4899-ppltc       1/1     Running   0          17d
rag-deploy-service-5b7887644c-sm58z         2/2     Running   0          110m
redis-deploy-service-f8866b56-kj9jz         1/1     Running   0          17d
vectorize-deploy-service-57f5f94ccf-sbhzp   2/2     Running   0          17d
web-deploy-service-74fbf7999f-r46rg         1/1     Running   0          2d
# 进入rag pod
root@openeuler:~# kubectl -n euler-copilot exec -it rag-deploy-service-5b7887644c-sm58z  -- bash
```
4. 设置PYTHONPATH
```bash
# 设置PYTHONPATH
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ export PYTHONPATH=$(pwd)
```
## 上传语料
### 2. 查看脚本帮助信息
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --help
usage: rag_kb_manager.pyc [-h] --method
                          {init_database_info,init_rag_info,init_database,clear_database,create_kb,del_kb,query_kb,create_kb_asset,del_kb_asset,query_kb_asset,up_corpus,del_corpus,query_corpus,stop_corpus_uploading_job}
                          [--database_url DATABASE_URL] [--vector_agent_name VECTOR_AGENT_NAME] [--parser_agent_name PARSER_AGENT_NAME]
                          [--rag_url RAG_URL] [--kb_name KB_NAME] [--kb_asset_name KB_ASSET_NAME] [--corpus_dir CORPUS_DIR]
                          [--corpus_chunk CORPUS_CHUNK] [--corpus_name CORPUS_NAME] [--up_chunk UP_CHUNK]
                          [--embedding_model {TEXT2VEC_BASE_CHINESE_PARAPHRASE,BGE_LARGE_ZH,BGE_MIXED_MODEL}] [--vector_dim VECTOR_DIM]
                          [--num_cores NUM_CORES]

optional arguments:
  -h, --help            show this help message and exit
  --method {init_database_info,init_rag_info,init_database,clear_database,create_kb,del_kb,query_kb,create_kb_asset,del_kb_asset,query_kb_asset,up_corpus,del_corpus,query_corpus,stop_corpus_uploading_job}
                        脚本使用模式，有init_database_info(初始化数据库配置)、init_database(初始化数据库)、clear_database（清除数据库）、create_kb(创建资产)、
                        del_kb(删除资产)、query_kb(查询资产)、create_kb_asset(创建资产库)、del_kb_asset(删除资产库)、query_kb_asset(查询
                        资产库)、up_corpus(上传语料,当前支持txt、html、pdf、docx和md格式)、del_corpus(删除语料)、query_corpus(查询语料)和
                        stop_corpus_uploading_job(上传语料失败后，停止当前上传任务)
  --database_url DATABASE_URL
                        语料资产所在数据库的url
  --vector_agent_name VECTOR_AGENT_NAME
                        向量化插件名称
  --parser_agent_name PARSER_AGENT_NAME
                        分词插件名称
  --rag_url RAG_URL     rag服务的url
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
  --embedding_model {TEXT2VEC_BASE_CHINESE_PARAPHRASE,BGE_LARGE_ZH,BGE_MIXED_MODEL}
                        初始化资产时决定使用的嵌入模型
  --vector_dim VECTOR_DIM
                        向量化维度
  --num_cores NUM_CORES
                        语料处理使用核数
```

### 3. 具体操作：
#### 步骤1：配置数据库和rag信息
- 配置数据库信息
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method init_database_info  --database_url postgresql+psycopg2://postgres:123456@pgsql-db-service:5432/postgres
# 注意：
# service为默认服务名，可根据实际修改；
# 如若需要更换数据库操作，请修改database_url，该URL是基于SQLAlchemy框架用于数据库连接的标识符。
```
- 配置rag信息
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method init_rag_info --rag_url http://0.0.0.0:8005
# 该命令可直接执行，8005是rag pod的默认端口
```

#### 步骤2：初始化数据库
- 初始化数据库信息
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method init_database 
# 注意： 
# 如果有更换数据库的操作可指定参数'--vector_agent_name VECTOR_AGENT_NAME'和 '--parser_agent_name PARSER_AGENT_NAME'；其中VECTOR_AGENT_NAME默认为vector, PARSER_AGENT_NAME默认为zhparser
```
- 清空数据库
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method clear_database
# 清空数据库请谨慎操作
```

#### 步骤3：创建资产
- 创建资产
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method create_kb --kb_name default_test
# 默认资产名为default_test，如需修改，需要同步修改values.yaml中rag章节中的下面字段，并进行helm更新操作:
# RAG内知识库名
#    knowledgebaseID: default_test
```

- 删除资产
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method del_kb --kb_name default_test
```
- 查询资产
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method query_kb
```
#### 步骤4：创建资产库
- 创建资产库
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method create_kb_asset --kb_name default_test --kb_asset_name default_test_asset
# 创建属于default_test的资产库
```
- 删除资产库
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method del_kb_asset --kb_name default_test --kb_asset_name default_test_asset
```

- 查询资产库
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method query_kb_asset --kb_name default_test
# 注意：资产是最上层的，资产库属于资产，且不能重名
```

#### 步骤5：上传语料
- 上传语料
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method up_corpus --corpus_dir ./scripts/docs/ --kb_name default_test --kb_asset_name default_test_asset
# 注意：
# 1. RAG容器用于存储用户语料的目录路径是'./scripts/docs/'。在执行相关命令前，请确保该目录下已有本地上传的语料。
# 2. 若语料已上传但查询未果，请检查宿主机上的待向量化语料目录（位于/home/euler-copilot/docs）的权限设置。
# 为确保无权限问题影响，您可以通过运行chmod 755 /home/euler-copilot/docs命令来赋予该目录最大访问权限。
```

- 删除语料
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method del_corpus --corpus_name abc.docx --kb_name default_test --kb_asset_name default_test_asset
# 上传的文件统一转换为docx
```

- 查询语料
```bash
# 查询指定名称的语料：
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method query_corpus --corpus_name 语料名.docx

# 查询所有语料：
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$ python3 scripts/rag_kb_manager.pyc --method query_corpus
```
- 停止上传任务
```bash
[eulercopilot@rag-deploy-service-7cb85d58c7-phpng rag-service]$python3 scripts/rag_kb_manager.pyc  --method stop_corpus_uploading_job
# 语料上传失败时，可执行该操作停止上传任务
```

## 网页端查看语料上传进度

您可以灵活设置端口转发规则，通过执行如下命令将容器端口映射到主机上的指定端口，并在任何设备上通过访问http://<主机IP>:<映射端口>（例如http://192.168.16.178:3000/）来查看语料上传的详细情况。
```bash
root@openeuler:~# kubectl port-forward rag-deploy-service-5b7887644c-sm58z 3000:8005 -n euler-copilot --address=0.0.0.0
# 注意: 3000是主机上的端口，8005是rag的容器端口，可修改映射到主机上的端口
```
## 验证上传后效果

您可以查看RAG的日志或直接在语料文档中提取问答对，随后通过EulerCopilot网页端发起提问，对比问题答案与文档语料中的信息，确保两者高度一致。一旦测试结果显示出高匹配度，该语料即被验证为有效并生效
```bash
root@openeuler:~# kubectl -n euler-copilot get pods
root@openeuler:~# kubectl logs rag-deploy-service-5b7887644c-sm58z  -n euler-copilot
```