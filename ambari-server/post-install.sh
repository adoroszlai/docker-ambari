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

# copy DBMS-specific create scripts to separate directories
# for easier sharing to DBMS container via volume
cd /var/lib/ambari-server/resources
for dbtype in $(/bin/ls -1 *CREATE.sql | cut -f3 -d'-' | sort -u); do
  mkdir -p sql/create/${dbtype}
  cp -v Ambari-DDL-${dbtype}-CREATE.sql sql/create/${dbtype}/
done

# hack: avoid stdout redirection
find /usr/lib -name serverConfiguration.py | xargs -r perl -wpl -i'' -e 's/self.SERVER_OUT_FILE =.*/self.SERVER_OUT_FILE = "\&1"/'
perl -wpl -i'' -e 's/> {([0-9])}/>{$1}/' /usr/sbin/ambari_server_main.py
