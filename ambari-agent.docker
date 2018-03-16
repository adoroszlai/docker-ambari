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

ARG FLAVOR
ARG HUB_REPO

FROM ${HUB_REPO}/ambari-base:${FLAVOR}

ENV AMBARI_AGENT_RUN_IN_FOREGROUND true
ENV CONF_DIR /etc/ambari-agent/conf

ADD ambari-agent.tar.gz /
RUN bash /var/lib/ambari-agent/install-helper.sh install

WORKDIR /
CMD [ "/usr/sbin/ambari-agent", "start" ]
