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

include vars.mk
include common.mk

DIST_URL ?= http://archive.apache.org/dist/ambari
FLAVORS ?= centos6 centos7
MODULES ?= ambari-agent ambari-server

UID ?= $(shell id -u)
GID ?= $(shell id -g)
HOME_IN_DOCKER := /ambari

AMBARI_SRC := apache-ambari-${AMBARI_RELEASE}-src
AMBARI_VERSION := ${AMBARI_RELEASE}.0.0
MODULE_PART_SEPARATOR := =
EXTRA_MODULES := $(if $(findstring ambari-server,${MODULES}),${COMMA}ambari-admin${COMMA}ambari-web,)

# Returns "module=build=flavor" for each element of the (module x flavor) matrix.
#
# $(call create-module-matrix,module-list)
define create-module-matrix
$(foreach flavor,${FLAVORS},$(addsuffix ${MODULE_PART_SEPARATOR}${AMBARI_RELEASE}${MODULE_PART_SEPARATOR}${flavor},$1))
endef

# Returns the path where Maven outputs the package each module.
#
# $(call get-packaged-module-path,module-list)
define get-packaged-module-path
$(foreach module,$1,${AMBARI_SRC}/${module}/target/repo/${module}.tar.gz)
endef

# Creates the given marker file and all its parent directories.
# Used for non-file targets.
#
# $(call create-marker-file,marker-file)
define create-marker-file
mkdir -p $(dir $1)
touch $1
endef

define module-to-words
$(subst ${MODULE_PART_SEPARATOR}, ,$1)
endef

define module-name
$(word 1, $(call module-to-words,$1))
endef

define build-name
$(word 2, $(call module-to-words,$1))
endef

define flavor-name
$(subst ${SPACE},-,$(wordlist 3, 1000, $(call module-to-words,$1)))
endef

define format-image-name
$1:$2-$3
endef

define module-to-image-name
$(subst ${SPACE},,          \
	$(call format-image-name, \
		$(call module-name,$1), \
		$(call build-name,$1),  \
		$(call flavor-name,$1)))
endef

MODULE_MATRIX := $(call create-module-matrix,${MODULES})
PACKAGED_MODULES := $(call get-packaged-module-path,${MODULES})
PACKAGED_MODULES_WILDCARD := $(subst target/repo,%,${PACKAGED_MODULES})
DEPLOY_TARGETS := $(foreach i,$(MODULE_MATRIX),deploy-${i})

debug:
	# AMBARI_RELEASE: ${AMBARI_RELEASE}
	# DIST_URL: ${DIST_URL}
	# EXTRA_MODULES: ${EXTRA_MODULES}
	# FLAVORS: ${FLAVORS}
	# MODULES: ${MODULES}
	# PWD: ${PWD}

build: ${MODULES}
deploy: ${DEPLOY_TARGETS}

${MODULES}: package
${MODULES}: %: $(call create-module-matrix,%)
package: source ${PACKAGED_MODULES}
source: ${AMBARI_SRC}
${MODULE_MATRIX}: %: .docker/${DOCKER_USERNAME}/modules/%

${DEPLOY_TARGETS}:
	docker push ${DOCKER_USERNAME}/$(call module-to-image-name,$(subst deploy-,,$@))

.docker/${DOCKER_USERNAME}/modules/%:
	$(eval module := $(call module-name,$*))
	$(eval build  := $(call build-name,$*))
	$(eval flavor := $(call flavor-name,$*))
	$(eval image := $(call format-image-name,${module},${build},${flavor}))
	# Building Docker image: ${image}
	cp -v ${module}/* ${AMBARI_SRC}/${module}/target/repo/
	docker build \
		--build-arg "FLAVOR=${flavor}" \
		--build-arg "HUB_REPO=${DOCKER_USERNAME}" \
		-t ${DOCKER_USERNAME}/${image} \
		${AMBARI_SRC}/${module}/target/repo
	$(call create-marker-file,$@)

${PACKAGED_MODULES_WILDCARD}: ${AMBARI_SRC}
	# Building and packaging Ambari ${AMBARI_RELEASE}
	docker run -i --rm --name ambari-builder \
		-u "${UID}:${GID}" \
		-v "${PWD}/$<:${HOME_IN_DOCKER}:delegated" \
		-v "${HOME}/.m2:${HOME_IN_DOCKER}/.m2:cached" \
		--env "HOME=${HOME_IN_DOCKER}" \
		-w "${HOME_IN_DOCKER}" \
		--entrypoint bash \
		${DOCKER_USERNAME}/ambari-builder -c \
			"mvn -Dcheckstyle.skip -Dfindbugs.skip -Drat.skip -DskipTests -Del.log=WARN \
				-am -pl $(subst ${SPACE},${COMMA},${MODULES})${EXTRA_MODULES} -DnewVersion=${AMBARI_VERSION} \
				clean package"

%-src: %-src.tar.gz
	tar xzmf $<

apache-ambari-%-src.tar.gz:
	curl -O ${DIST_URL}/$(patsubst apache-%-src.tar.gz,%,$@)/$@

clean:
	# Removing sources and marker files for Ambari ${AMBARI_RELEASE}
	rm -fr ${AMBARI_SRC} ${AMBARI_SRC}.tar.gz .docker/${DOCKER_USERNAME}/*${MODULE_PART_SEPARATOR}${AMBARI_RELEASE}${MODULE_PART_SEPARATOR}*

.PHONY: build clean debug deploy help package source
.SECONDARY: ${AMBARI_SRC}.tar.gz
.SUFFIXES:
