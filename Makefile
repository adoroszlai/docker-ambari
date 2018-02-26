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

UID ?= $(shell id -u)
GID ?= $(shell id -g)

build:
	# HOME: ${HOME}
	# PWD: ${PWD}
	# USER: ${USER}
	docker run -i --rm --name test \
		-u "${UID}:${GID}" \
		--env "HOME=/ambari" \
		-v "${PWD}/test:/ambari:delegated" \
		-w "/ambari" \
		--entrypoint bash \
		centos:7 -c "id; pwd; cd ~; pwd"

.PHONY: build
