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

: ${AMBARI_VERSION:=3.0.0.0-SNAPSHOT}
: ${BUILD:=latest}
: ${FLAVORS:="debian8"}
: ${GIT_REF:=trunk}
: ${GIT_REPO:=https://github.com/apache/ambari}
: ${HUB_REPO:=adoroszlai}
: ${MODULES:="ambari-agent ambari-server"}

function clean {
  rm -fr ambari
}

function clone-ambari {
  echo "Building $AMBARI_VERSION from $GIT_REPO/tree/$GIT_REF"

  if [[ $GIT_REF == trunk || $GIT_REF == branch* || $GIT_REF == AMBARI* || $GIT_REF == release* ]]; then
    git clone -b ${GIT_REF} --depth 1 ${GIT_REPO} ambari
  else
    git clone --no-checkout ${GIT_REPO} ambari
    cd ambari
    git checkout ${GIT_REF}
    cd ..
  fi
}

function maven-build {
  docker build -t ${HUB_REPO}/ambari-builder - < builder.docker

  docker run -i --rm --name ambari-builder \
    -v "$(pwd)/ambari:/ambari:delegated" \
    -v "${HOME}/.m2:/root/.m2:cached" \
    -w "/ambari" \
    --entrypoint bash \
    ${HUB_REPO}/ambari-builder <<-EOF
      mvn versions:set -DnewVersion=${AMBARI_VERSION}; \
      pushd ambari-metrics; \
      mvn versions:set -DnewVersion=${AMBARI_VERSION}; \
      popd; \
      mvn -Dcheckstyle.skip -Dfindbugs.skip -Drat.skip -DskipTests -Del.log=WARN \
        -am -pl ambari-admin,ambari-agent,ambari-server,ambari-web \
        -DnewVersion=${AMBARI_VERSION} clean package
EOF
}

function build-ambari {
  clone-ambari
  maven-build
}

function build-module {
  local module=$1
  local flavor=$2

  cp -v ${module}/* ambari/${module}/target/repo/
  docker build \
    --build-arg "AMBARI_VERSION=$AMBARI_VERSION" \
    --build-arg "BUILD=$BUILD" \
    --build-arg "FLAVOR=$flavor" \
    --build-arg "HUB_REPO=$HUB_REPO" \
    -t ${HUB_REPO}/${module}:${BUILD}-${flavor} \
    ambari/${module}/target/repo
}

function build-modules {
  for flavor in ${FLAVORS}; do
    for module in ${MODULES}; do
      build-module $module $flavor
    done
  done
}

function help {
  echo "Usage: $0 (all|ambari|modules|clean)"
}

target=${1:-all}

case $target in
  clean)
    clean
    ;;
  all)
    build-ambari
    build-modules
    ;;
  ambari)
    build-ambari
    ;;
  modules)
    build-modules
    ;;
  *)
    help
    ;;
esac
