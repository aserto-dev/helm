SHELL 	   		:= ${shell which bash}

NO_COLOR   		:= \033[0m
OK_COLOR   		:= \033[32;01m
ERR_COLOR  		:= \033[31;01m
WARN_COLOR 		:= \033[36;01m
ATTN_COLOR 		:= \033[33;01m

CHART_REPO		:= "oci://ghcr.io/aserto-dev/helm"
CHARTS_DIR 		:= charts
CHARTS 			:= ${shell ls ${CHARTS_DIR}}
BUMP_PART 		?= patch

CT_VERSION		:= 3.11.0

BIN_DIR			:= ./bin
EXT_DIR			:= ./.ext
EXT_BIN_DIR		:= ${EXT_DIR}/bin
EXT_TMP_DIR		:= ${EXT_DIR}/tmp

CT_LINT_CMD		:= ${EXT_BIN_DIR}/ct lint --config ct.yaml \
	--chart-yaml-schema ${EXT_BIN_DIR}/etc/chart_schema.yaml \
	--lint-conf ${EXT_BIN_DIR}/etc/lintconf.yaml \
	--helm-repo-extra-args "aserto-helm=-u gh -p ${GITHUB_TOKEN}"


.PHONY: deps
deps: install-ct install-bumpversion;

.PHONY: clean
clean: ${addprefix clean-,${CHARTS}}

.PHONY: lint
lint:
	@echo -e "${ATTN_COLOR}==> $@ ${NO_COLOR}"
	@${CT_LINT_CMD}

.PHONY: update
update: ${addprefix update-,${CHARTS}}

.PHONY: build
build: ${addprefix build-,${CHARTS}}

.PHONY: package
package: ${addprefix package-,${CHARTS}}

.PHONY: push
push: ${addprefix push-,${CHARTS}}

.PHONY: bump
bump: ${addprefix bump-,${CHARTS}}

.PHONY: release
release: build package push

.PHONY: clean-%
clean-%:
	@echo -e "${ATTN_COLOR}==> clean $* ${NO_COLOR}"
	@rm -rf ${CHARTS_DIR}/$*/build

.PHONY: lint-%
lint-%:
	@echo -e "${ATTN_COLOR}==> lint $* ${NO_COLOR}"
	@${CT_LINT_CMD} --charts ${CHARTS_DIR}/$*

.PHONY: test-%
test-%:
	@echo -e "${ATTN_COLOR}==> test $* ${NO_COLOR}"
	@uv run --project tools/ktest tools/ktest/ktest.py charts/$*/test/tests.yaml

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
push-% bump-% version-%: CHART_VERSION = ${shell cat ${CHARTS_DIR}/$*/Chart.yaml | yq '.version'}

.PHONY: push-%
push-%:
	@echo -e "${ATTN_COLOR}==> push $*:${CHART_VERSION} ${NO_COLOR}"
	@helm push ${CHARTS_DIR}/$*/build/$*-${CHART_VERSION}.tgz ${CHART_REPO}

.PHONY: release-%
release-%: update-% build-% package-% push-%;

.PHONY: bump-%
bump-%:
	@echo -e "${ATTN_COLOR}==> bump ${BUMP_PART} $* (${CHART_VERSION}) ${NO_COLOR}"
	@bumpversion --no-tag --no-commit --allow-dirty --current-version ${CHART_VERSION} \
		${BUMP_PART} ${CHARTS_DIR}/$*/Chart.yaml
	@echo -e "New version: $$(cat ${CHARTS_DIR}/$*/Chart.yaml | yq '.version')"

.PHONY: version-%
version-%:
	@echo -e "${ATTN_COLOR}==>  $* (${CHART_VERSION}) ${NO_COLOR}"

.PHONY: install-ct
install-ct: ${EXT_TMP_DIR} ${EXT_BIN_DIR}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@gh release download v${CT_VERSION} --repo https://github.com/helm/chart-testing \
		--pattern "chart-testing_${CT_VERSION}_$$(uname -s | tr '[:upper:]' '[:lower:]')_$$(uname -m).tar.gz" \
		--output "${EXT_TMP_DIR}/chart-testing.tar.gz" --clobber
	@tar -xvf ${EXT_TMP_DIR}/chart-testing.tar.gz --directory ${EXT_BIN_DIR} ct etc/ &> /dev/null
	@chmod +x ${EXT_BIN_DIR}/ct
	@${EXT_BIN_DIR}/ct version

.PHONY: install-bumpversion
install-bumpversion: ${EXT_TMP_DIR} ${EXT_BIN_DIR}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@pip install bump2version

${BIN_DIR}:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@mkdir -p ${BIN_DIR}

${EXT_BIN_DIR}:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@mkdir -p ${EXT_BIN_DIR}

${EXT_TMP_DIR}:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@mkdir -p ${EXT_TMP_DIR}
