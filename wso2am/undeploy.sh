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
prgdir=$(dirname "$0")
script_path=$(cd "$prgdir"; pwd)
common_folder=$(cd "${script_path}/../common/scripts/"; pwd)

product_profiles=(default api-key-manager api-store api-publisher gateway-manager gateway-worker)

full_deployment=false

echo "${common_folder}/undeploy.sh wso2am-default"
bash "${common_folder}/undeploy.sh" "wso2am-default"

sleep 5

echo "Undeploying MySQL Services and RCs for Conf and Gov remote mounting..."
bash $script_path/../common/wso2-shared-dbs/undeploy.sh 

kubectl delete rc,services,pods -l name="mysql-apim-db"
