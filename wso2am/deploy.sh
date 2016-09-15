#!/bin/bash
# ------------------------------------------------------------------------
#
# Copyright 2016 WSO2, Inc. (http://wso2.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

# ------------------------------------------------------------------------

default_port=32003
km_port=32013
publisher_port=32016
store_port=32018
gateway_manager_port=32007
gateway_worker_port=32011

prgdir=$(dirname "$0")
script_path=$(cd "$prgdir"; pwd)
common_scripts_folder=$(cd "${script_path}/../common/scripts/"; pwd)
source "${common_scripts_folder}/base.sh"

# Deploy using separate profiles
function distributed {
    # deploy services
    bash "${common_scripts_folder}/deploy-kubernetes-service.sh" "wso2am" "api-key-manager" && \
    bash "${common_scripts_folder}/deploy-kubernetes-service.sh" "wso2am" "api-store" && \
    bash "${common_scripts_folder}/deploy-kubernetes-service.sh" "wso2am" "api-publisher" && \
    bash "${common_scripts_folder}/deploy-kubernetes-service.sh" "wso2am" "gateway-manager" && \
    #    bash "${common_scripts_folder}/deploy-kubernetes-service.sh" "gateway-worker" && \

    # deploy the controllers
    bash "${common_scripts_folder}/deploy-kubernetes-rc.sh" "wso2am" "api-key-manager" && \
    bash "${common_scripts_folder}/wait-until-server-starts.sh" "api-key-manager" "${km_port}" && \

    bash "${common_scripts_folder}/deploy-kubernetes-rc.sh" "wso2am" "api-store" && \
    bash "${common_scripts_folder}/wait-until-server-starts.sh" "api-store" "${store_port}" && \

    bash "${common_scripts_folder}/deploy-kubernetes-rc.sh" "wso2am" "api-publisher" && \
    bash "${common_scripts_folder}/wait-until-server-starts.sh" "api-publisher" "${publisher_port}" && \

    bash "${common_scripts_folder}/deploy-kubernetes-rc.sh" "wso2am" "gateway-manager" && \
    bash "${common_scripts_folder}/wait-until-server-starts.sh" "gateway-manager" "${gateway_manager_port}"

    #    bash "${common_scripts_folder}/deploy-kubernetes-rc.sh" "gateway-worker" && \
    #    bash "${common_scripts_folder}/wait-until-server-starts.sh" "gateway-worker" "${gateway_worker_port}"
}

while getopts :dh FLAG; do
    case $FLAG in
        d)
            deployment_pattern="distributed"
            ;;
        h)
            showUsageAndExitDistributed
            ;;
        \?)
            showUsageAndExitDistributed
            ;;
    esac
done

validateKubeCtlConfig

bash $script_path/../common/wso2-shared-dbs/deploy.sh

# deploy DB service and rc
echo "Deploying APIM database Service..."
kubectl create -f "$script_path/mysql-apimdb-service.yaml"

echo "Deploying APIM database Replication Controller..."
kubectl create -f "$script_path/mysql-apimdb-controller.yaml"

# wait till mysql is started
# TODO: find a better way to do this
sleep 10

if [ "$deployment_pattern" = "distributed" ]; then
    distributed
else
    default "${default_port}"
fi

pods=$(kubectl get pods --output=jsonpath={.items..metadata.name})
json='['
for pod in $pods; do
         hostip=$(kubectl get pods "$pod" --output=jsonpath={.status.hostIP})
         lable=$(kubectl get pods "$pod" --output=jsonpath={.metadata.labels.name})
         servicedata=$(kubectl describe svc "$lable")
         json+='{"hostIP" :"'$hostip'", "lable" :"'$lable'", "ports" :['
         declare -a dataarray=($servicedata)
         let count=0
         for data in ${dataarray[@]}  ; do
            if [ "$data" = "NodePort:" ]; then
            IFS='/' read -a myarray <<< "${dataarray[$count+2]}"
            json+='{'
            json+='"protocol" :"'${dataarray[$count+1]}'",  "port" :"'${myarray[0]}'"'
            json+="},"
            fi

         ((count+=1))
         done
         i=$((${#json}-1))
         lastChr=${json:$i:1}

         if [ "$lastChr" = "," ]; then
         json=${json:0:${#json}-1}
         fi

         json+="]},"

done
json=${json:0:${#json}-1}

json+="]"

echo $json;

cat > data.json << EOF1
$json
EOF1
