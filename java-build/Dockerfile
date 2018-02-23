# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM maven:3.5-jdk-8

ARG AMBARI_VERSION=2.0.0.0-SNAPSHOT
ARG GIT_REF=trunk
ARG GIT_REPO=https://github.com/apache/ambari

RUN apt-get update -q -y \
  && apt-get install -y --no-install-recommends \
    curl \
    git \
    make \
    python-setuptools \
    python2.7 \
    python2.7-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /
RUN git clone --no-checkout ${GIT_REPO} ambari

WORKDIR /ambari
RUN git checkout ${GIT_REF}
RUN mvn versions:set -DnewVersion=${AMBARI_VERSION} \
  && cd ambari-metrics && mvn versions:set -DnewVersion=${AMBARI_VERSION} && cd .. \
  && mvn -DskipTests -Dcheckstyle.skip -Drat.skip -Dfindbugs.skip -DnewVersion=${AMBARI_VERSION} \
    -am -pl ambari-admin,ambari-agent,ambari-metrics,ambari-server,ambari-web \
    clean package
