#!/usr/bin/env bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e -u

: ${AMBARI_VERSION:=2.0.0.0-SNAPSHOT}
: ${GIT_REF:=trunk}
: ${GIT_REPO:=https://github.com/apache/ambari}

echo "Building $AMBARI_VERSION from $GIT_REPO/tree/$GIT_REF"

if [[ $GIT_REF == trunk || $GIT_REF == branch* || $GIT_REF == AMBARI* || $GIT_REF == release* ]]; then
  git clone -b ${GIT_REF} --depth 1 ${GIT_REPO} ambari
  cd ambari
else
  git clone --no-checkout ${GIT_REPO} ambari
  cd ambari
  git checkout ${GIT_REF}
fi

mvn versions:set -DnewVersion=${AMBARI_VERSION}
pushd ambari-metrics
mvn versions:set -DnewVersion=${AMBARI_VERSION}
popd

mvn -Dcheckstyle.skip -Dfindbugs.skip -Drat.skip -DskipTests -Del.log=WARN \
  -am -pl ambari-admin,ambari-agent,ambari-server,ambari-web \
  -DnewVersion=${AMBARI_VERSION} clean package
