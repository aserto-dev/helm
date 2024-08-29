SHELL 	   		:= ${shell which bash}

NO_COLOR   		:= \033[0m
OK_COLOR   		:= \033[32;01m
ERR_COLOR  		:= \033[31;01m
WARN_COLOR 		:= \033[36;01m
ATTN_COLOR 		:= \033[33;01m

CHART_REPO		:= "oci://ghcr.io/aserto-dev/helm"

CHARTS_DIR := charts
CHARTS := ${shell ls ${CHARTS_DIR}}
BUMP_PART ?= patch

.PHONY: clean
clean: ${addprefix clean-,${CHARTS}}

.PHONY: lint
lint:
	@echo -e "${ATTN_COLOR}==> $@ ${NO_COLOR}"
	@ct lint --config ct.yaml --helm-repo-extra-args "aserto-helm=-u gh -p ${GITHUB_TOKEN}"

.PHONY: update
update: ${addprefix update-,${CHARTS}}

.PHONY: build
build: ${addprefix build-,${CHARTS}}

.PHONY: package
package: ${addprefix package-,${CHARTS}}

.PHONY: push
push: ${addprefix push-,${CHARTS}}

.PHONY: release
release: build package push

.PHONY: bump
bump: ${addprefix bump-,${CHARTS}}

.PHONY: clean-%
clean-%:
	@echo -e "${ATTN_COLOR}==> clean $* ${NO_COLOR}"
	@rm -rf ${CHARTS_DIR}/$*/build

.PHONY: lint-%
lint-%:
	@echo -e "${ATTN_COLOR}==> lint $* ${NO_COLOR}"
	@ct lint --charts ${CHARTS_DIR}/$* --config ct.yaml --helm-repo-extra-args "aserto-helm=-u gh -p ${GITHUB_TOKEN}"

.PHONY: update-%
update-%:
	@echo -e "${ATTN_COLOR}==> update $* ${NO_COLOR}"
	helm dependency update ${CHARTS_DIR}/$*

.PHONY: build-%
build-%:
	@echo -e "${ATTN_COLOR}==> build $* ${NO_COLOR}"
	@helm dependency build ${CHARTS_DIR}/$*

.PHONY: package-%
package-%:
	@echo -e "${ATTN_COLOR}==> package $* ${NO_COLOR}"
	@mkdir -p ${CHARTS_DIR}/$*/build
	@helm package ${CHARTS_DIR}/$* -u -d ${CHARTS_DIR}/$*/build

# Pattern-specific variable assignment.
# https://www.gnu.org/software/make/manual/html_node/Pattern_002dspecific.html
push-%: CHART_VERSION = ${shell cat ${CHARTS_DIR}/$*/Chart.yaml | yq '.version'}

.PHONY: push-%
push-%:
	@echo -e "${ATTN_COLOR}==> push $*:${CHART_VERSION} ${NO_COLOR}"
	@helm push ${CHARTS_DIR}/$*/build/$*-${CHART_VERSION}.tgz ${CHART_REPO}

# Pattern-specific variable assignment.
# https://www.gnu.org/software/make/manual/html_node/Pattern_002dspecific.html
bump-%: CHART_VERSION = ${shell cat ${CHARTS_DIR}/$*/Chart.yaml | yq '.version'}

.PHONY: bump-%
bump-%:
	@echo -e "${ATTN_COLOR}==> bump ${BUMP_PART} $* (${CHART_VERSION}) ${NO_COLOR}"
	@bumpversion --no-tag --no-commit --allow-dirty --current-version ${CHART_VERSION} \
		${BUMP_PART} ${CHARTS_DIR}/$*/Chart.yaml
	@echo -e "New version: $$(cat ${CHARTS_DIR}/$*/Chart.yaml | yq '.version')"

