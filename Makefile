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
FLAVORS ?= centos6 centos7 debian7 ubuntu16
LAYERS ?= $(if $(findstring [base],${TRAVIS_COMMIT_MESSAGE}),base final,final)
MODULES ?= ambari-agent ambari-server

UID ?= $(shell id -u)
GID ?= $(shell id -g)
HOME_IN_DOCKER := /ambari

AMBARI_SRC := apache-ambari-${AMBARI_RELEASE}-src
AMBARI_VERSION := ${AMBARI_RELEASE}.0.0
MODULE_PART_SEPARATOR := =
EXTRA_MODULES := $(if $(findstring ambari-server,${MODULES}),${COMMA}ambari-admin${COMMA}ambari-web,)
TAG := $(if ${TRAVIS_TAG},-${TRAVIS_TAG},)

# Returns "layer=module=build=flavor" for each element of the (layer x module x flavor) matrix,
#
# $(call create-module-matrix,module-list)
define create-module-matrix
$(foreach layer,${LAYERS}, \
	$(foreach flavor,${FLAVORS}, \
		$(addprefix ${layer}${MODULE_PART_SEPARATOR},$(addsuffix ${MODULE_PART_SEPARATOR}${AMBARI_RELEASE}${MODULE_PART_SEPARATOR}${flavor},$1))))
endef

# Returns the path where Maven outputs the package each module.
#
# $(call get-packaged-module-path,module-list)
define get-packaged-module-path
$(foreach module,$1,${AMBARI_SRC}/${module}/target/repo/${module}.tar.gz)
endef

define module-to-words
$(subst ${MODULE_PART_SEPARATOR}, ,$1)
endef

define layer-name
$(eval layer := $(word 1, $(call module-to-words,$1)))$(if $(findstring final,${layer}),${EMPTY},-${layer})
endef

define module-name
$(word 2, $(call module-to-words,$1))
endef

define build-name
$(word 3, $(call module-to-words,$1))
endef

define flavor-name
$(subst ${SPACE},-,$(wordlist 4, 1000, $(call module-to-words,$1)))
endef

# Formats Docker image name.
# Layer name should include separator, since it's optional.
#
# $(call format-image-name,module,layer,build,flavor)
define format-image-name
$1$2:$3-$4
endef

define module-to-image-name
$(subst ${SPACE},,          \
	$(call format-image-name, \
		$(call module-name,$1), \
		$(call layer-name,$1), \
		$(call build-name,$1),  \
		$(call flavor-name,$1)))
endef

ifeq (${BUILD_IN_DOCKER},true)
define build-ambari
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
endef
else
define build-ambari
	cd $< && \
		mvn -Dcheckstyle.skip -Dfindbugs.skip -Drat.skip -DskipTests -Del.log=WARN \
			-am -pl $(subst ${SPACE},${COMMA},${MODULES})${EXTRA_MODULES} -DnewVersion=${AMBARI_VERSION} \
			clean package
endef
endif

MODULE_MATRIX := $(call create-module-matrix,${MODULES})
PACKAGED_MODULES := $(call get-packaged-module-path,${MODULES})
PACKAGED_MODULES_WILDCARD := $(subst target/repo,%,${PACKAGED_MODULES})
DEPLOYABLES := $(foreach i,$(MODULE_MATRIX),deploy-${i})

#
# main targets
#
build: ${MODULES}
deploy: ${DEPLOYABLES}
package: source ${PACKAGED_MODULES}
source: ${AMBARI_SRC}

need_base_layer := $(findstring base,${LAYERS})
ifdef need_base_layer
${MODULES}: package
endif
${MODULES}: %: $(call create-module-matrix,%)

# push Docker images
${DEPLOYABLES}:
	$(eval base_tag := ${DOCKER_USERNAME}/$(call module-to-image-name,$(subst deploy-,,$@)))
	if [ -n "${TAG}" ]; then docker tag ${base_tag} ${base_tag}${TAG}; docker push ${base_tag}${TAG}; fi
	docker push ${base_tag}

# build Docker images
${MODULE_MATRIX}:
	$(eval layer  := $(call layer-name,$@))
	$(eval module := $(call module-name,$@))
	$(eval build  := $(call build-name,$@))
	$(eval flavor := $(call flavor-name,$@))
	$(eval image := $(call format-image-name,${module},${layer},${build},${flavor}))
	$(eval build_dir := $(if $(findstring base,${layer}),${AMBARI_SRC}/${module}/target/repo,${module}))
	# Building Docker image: ${image} in ${build_dir}
	if [ "${layer}" = "-base" ]; then cp -v ${module}.docker ${build_dir}/Dockerfile; fi; \
	docker build \
		--build-arg "AMBARI_BUILD=${build}" \
		--build-arg "FLAVOR=${flavor}" \
		--build-arg "HUB_REPO=${DOCKER_USERNAME}" \
		-t ${DOCKER_USERNAME}/${image} \
		${build_dir}

# build Ambari from source
${PACKAGED_MODULES_WILDCARD}: ${AMBARI_SRC}
	# Building and packaging Ambari ${AMBARI_RELEASE}
	$(call build-ambari)

# extract Ambari source
%-src: %-src.tar.gz
	tar xzmf $<

# download Ambari source
apache-ambari-%-src.tar.gz:
	curl -O ${DIST_URL}/$(patsubst apache-%-src.tar.gz,%,$@)/$@

#
# utilities for local build
#
BASE_IMAGES := $(foreach flavor,${FLAVORS},${flavor}=base)

pull: ${BASE_IMAGES}
${BASE_IMAGES}:
	$(eval flavor := $(firstword $(call module-to-words,$@)))
	docker pull adoroszlai/ambari-base:${flavor}

clean:
	# Removing sources and marker files for Ambari ${AMBARI_RELEASE}
	rm -fr ${AMBARI_SRC} ${AMBARI_SRC}.tar.gz

debug:
	# AMBARI_RELEASE: ${AMBARI_RELEASE}
	# BASE_IMAGES: ${BASE_IMAGES}
	# DEPLOYABLES: ${DEPLOYABLES}
	# DIST_URL: ${DIST_URL}
	# EXTRA_MODULES: ${EXTRA_MODULES}
	# FLAVORS: ${FLAVORS}
	# LAYERS: ${LAYERS}
	# MODULES: ${MODULES}
	# MODULE_MATRIX: ${MODULE_MATRIX}
	# PACKAGED_MODULES: ${PACKAGED_MODULES}
	# PACKAGED_MODULES_WILDCARD: ${PACKAGED_MODULES_WILDCARD}
	# PWD: ${PWD}

.PHONY: build clean debug deploy package pull source ${BASE_IMAGES} ${MODULE_MATRIX}
.SECONDARY: ${AMBARI_SRC}.tar.gz ${PACKAGED_MODULES}
.SUFFIXES:
