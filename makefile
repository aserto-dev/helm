SHELL 	   		:= $(shell which bash)

NO_COLOR   		:= \033[0m
OK_COLOR   		:= \033[32;01m
ERR_COLOR  		:= \033[31;01m
WARN_COLOR 		:= \033[36;01m
ATTN_COLOR 		:= \033[33;01m

CHART_REPO		:= "oci://ghcr.io/aserto-dev/helm"

ifndef CHART
$(error CHART must be set)
endif

CHART_DIR		:= charts/${CHART}
CHART_VERSION   := $(shell cat ${CHART_DIR}/Chart.yaml | yq '.version')

.PHONY: clean
clean:
	@echo -e "$(ATTN_COLOR)==> $@ ${CHART} $(NO_COLOR)"
	@rm -rf ${CHART_DIR}/build

.PHONY: update
update:
	@echo -e "$(ATTN_COLOR)==> $@ ${CHART} $(NO_COLOR)"
	@helm dependency update ${CHART_DIR}

.PHONY: build
build:
	@echo -e "$(ATTN_COLOR)==> $@ ${CHART} $(NO_COLOR)"
	@helm dependency build ${CHART_DIR}

.PHONY: package
package:
	@echo -e "$(ATTN_COLOR)==> $@ ${CHART} $(NO_COLOR)"
	@mkdir -p ${CHART_DIR}/build
	@helm package ${CHART_DIR} -u -d ${CHART_DIR}/build

.PHONY: push
push:
	@echo -e "$(ATTN_COLOR)==> $@ ${CHART}:$(CHART_VERSION) $(NO_COLOR)"
	@helm push ${CHART_DIR}/build/${CHART}-$(CHART_VERSION).tgz $(CHART_REPO)

.PHONY: lint
lint:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	ct lint --config ct.yaml --helm-repo-extra-args "aserto-helm=-u gh -p ${GITHUB_TOKEN}"


.PHONY: release
release: build package push
