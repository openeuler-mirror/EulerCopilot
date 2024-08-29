# 本地语料上传指南
- RAG是一个检索增强的模块，该指南主要是为rag提供命令行的方式进行资产管理、资产库管理和语料资产管理；
  对于资产管理提供了资产创建、资产查询和资产删除等功能；
  对于资产库管理提供了资产库创建、资产库查询和资产库删除等功能；
  对于语料资产管理提供了语料上传、语料查询和语料删除等功能，且语料资产管理的语料上传部分依赖语料预处理功能；
  对于语料预处理功能提供了文档内容解析、文档格式转换和文档切功能。

- rag当前仅面向管理员进行资产管理，对于管理员而言，可以拥有多个资产，一个资产包含多个资产库（不同资产库的使用的向量化模型可能不同），一个资产库对应一个语料资产。

- 本地语料上传指南是用户构建项目专属语料的指导，当前支持docx、pdf、markdown和txt文件上传，推荐使用docx上传。

## 准备工作
1. 将本地语料保存到服务器的`/home/data/corpus`目录
2. 更新EulerCopilot服务：
```
helm upgrade -n euler-copilot service .
```
4. 进入到rag容器：
`kubectl -n <namespace> exec -it <pod_id> -- bash`

## 上传语料
### 1. 设置PYTHONPATH
```
cd rag-service/
# 设置PYTHONPATH
export PYTHONPATH=$(pwd)
```
### 2. 查看脚本帮助信息

```bash:
python3 scripts/rag_kb_manager.pyc --help
usage: rag_kb_manager.pyc [-h] --method
                          {init_database_info,init_rag_info,init_database,clear_database,create_kb,del_kb,query_kb,create_kb_asset,del_kb_asset,query_kb_asset,up_corpus,del_corpus,query_corpus,stop_corpus_uploading_job}
                          [--database_url DATABASE_URL] [--vector_agent_name VECTOR_AGENT_NAME] [--parser_agent_name PARSER_AGENT_NAME]
                          [--rag_url RAG_URL] [--kb_name KB_NAME] [--kb_asset_name KB_ASSET_NAME] [--corpus_dir CORPUS_DIR] [--corpus_chunk CORPUS_CHUNK]
                          [--corpus_name CORPUS_NAME] [--up_chunk UP_CHUNK]
                          [--embedding_model {TEXT2VEC_BASE_CHINESE_PARAPHRASE,BGE_LARGE_ZH,BGE_MIXED_MODEL}] [--vector_dim VECTOR_DIM]
                          [--num_cores NUM_CORES]

optional arguments:
  -h, --help            show this help message and exit
  --method {init_database_info,init_rag_info,init_database,clear_database,create_kb,del_kb,query_kb,create_kb_asset,del_kb_asset,query_kb_asset,up_corpus,del_corpus,query_corpus,stop_corpus_uploading_job}
                        脚本使用模式，有init_database_info(初始化数据库配置)、init_database(初始化数据库)、clear_database（清除数据库）、create_kb(创建资产)、
                        del_kb(删除资产)、query_kb(查询资产)、create_kb_asset(创建资产库)、del_kb_asset(删除资产库)、query_kb_asset(查询
                        资产库)、up_corpus(上传语料,当前支持txt、html、pdf、docx和md格式)、del_corpus(删除语料)、query_corpus(查询语料)和 stop_corpus_uploading_job(上传语料失败后，停止当前上传任务)
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
`python3 scripts/rag_kb_manager.pyc --method init_database_info  --database_url postgresql+psycopg2://postgres:123456@pgsql-db-$(服务名):5432/postgres`
(database_url是数据库基于sqlalchemy链接的url，请根据实际修改)

- 配置rag信息
`python3 scripts/rag_kb_manager.pyc --method init_rag_info --rag_url http://0.0.0.0:8005`

#### 步骤2：初始化数据库
- 初始化数据库信息
 `python scripts/rag_kb_manager.pyc --method  init_database --vector_agent_name VECTOR_AGENT_NAME  --parser_agent_name PARSER_AGENT_NAME`（注意：修改VECTOR_AGENT_NAME和PARSER_AGENT_NAME）
- 清空数据库
`python3 scripts/rag_kb_manager.pyc --method clear_database`

#### 步骤3：创建资产
- 创建资产
`python3 scripts/rag_kb_manager.pyc --method create_kb --kb_name default_test`
- 删除资产
`python3 scripts/rag_kb_manager.pyc --method del_kb --kb_name default_test`
- 查询资产
`python3 scripts/rag_kb_manager.pyc --method query_kb`
 
#### 步骤4：创建资产库
- 创建资产库
`python3 scripts/rag_kb_manager.pyc --method create_kb_asset --kb_name default_test --kb_asset_name default_test_asset`
- 删除资产库
`python3 scripts/rag_kb_manager.pyc --method del_kb_asset --kb_name default_test --kb_asset_name default_test_asset`
- 查询资产库
`python3 scripts/rag_kb_manager.pyc --method query_kb_asset --kb_name default_test`(注意：资产是最上层的，资产库属于资产，且不能重名)  

#### 步骤5：上传语料
- 上传语料
`python3 scripts/rag_kb_manager.pyc --method up_corpus --corpus_dir ./scripts/docs/ --kb_name default_test --kb_asset_name default_test_asset`
- 删除语料
`python3 scripts/rag_kb_manager.pyc --method del_corpus –-corpus_name abc.docx(上传的文件统一转换为docx)  --kb_name default_test --kb_asset_name default_test_asset`
- 查询语料
`python3 scripts/rag_kb_manager.pyc --method query_corpus --n corpus_ame abc.docx (ilike ‘%%’模糊查询，一行返回一个语料名以及上传时间) --kb_name default_test –-kb_asset_name default_test_asset`
 
- 语料上传失败时，停止上传任务
`python asset_manager.py –-method stop_embdding_jobs`

## 网页端查看语料上传
您可以根据需要进行端口转发，并在网页端查看语料上传详情。
```bash
kubectl port-forward <pod_id> $(主机上的端口):$(容器端口) -n euler-copilot  --address=0.0.0.0
```
端口映射后可以直接用<主机IP:端口>去访问，例如`http://192.168.16.178:3000/`
