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

ARG AMBARI_VERSION
ARG BUILD
ARG HUB_REPO

ENV AMBARI_SERVER_RUN_IN_FOREGROUND true
ENV CONF_DIR /etc/ambari-server/conf

COPY --from=${HUB_REPO}/ambari-build:${BUILD} /ambari/ambari-server/target/ambari-server-${AMBARI_VERSION}-dist/ /
RUN bash /var/lib/ambari-server/install-helper.sh install

WORKDIR /tmp
COPY post-install.sh ./
RUN chmod +x post-install.sh && ./post-install.sh && rm post-install.sh

WORKDIR /
CMD [ "/usr/sbin/ambari-server", "start" ]
