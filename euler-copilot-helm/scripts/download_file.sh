#!/bin/bash
 
download_and_extract_files() {  
    local BASE_URL=$1  
    local TARGET_DIR="/home/EulerCopilot/models" 
    shift  
    local FILES=("$@")  
  
    yum -y install tar wget  
  
    if [ ! -d "${TARGET_DIR}" ]; then  
        echo "Creating directory ${TARGET_DIR}..."  
        mkdir -p "${TARGET_DIR}"  
    fi  
  
    for FILE in "${FILES[@]}"; do  
        FULL_URL="${BASE_URL}${FILE}"  
  
        if [ ! -f "${FILE}" ]; then  
            echo "Downloading ${FULL_URL}..."  
            wget -O "${FILE}" "${FULL_URL}"  
            if [ $? -ne 0 ]; then  
                echo "Failed to download ${FILE}."  
                continue  
            fi  
        else  
            echo "${FILE} already exists, skipping download."  
        fi  
  
        echo "Extracting ${FILE} to ${TARGET_DIR}..."  
        if [[ "${FILE}" == *.tar.gz ]]; then  
            if ! tar -xzvf "${FILE}" -C "${TARGET_DIR}" 2>&1 | grep -q 'Error is not recoverable'; then  
                echo "${FILE} extracted successfully."  
                rm "${FILE}"  
            else  
                echo "Failed to extract ${FILE}: it may be corrupt or not a tar.gz file."  
                rm "${FILE}"  
            fi  
        else  
            echo "Unsupported file format: ${FILE}"  
            continue  
        fi  
    done  
}  
  
BASE_URL="https://repo.oepkgs.net/openEuler/rpm/openEuler-22.03-LTS/contrib/EulerCopilot/"  
FILES=("bge-mixed-model.tar.gz" "text2vec-base-chinese-paraphrase.tar.gz" "bge-reranker-large.tar.gz")  
  
download_and_extract_files "${BASE_URL}" "${FILES[@]}"
