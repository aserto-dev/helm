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
CHART_VERSION   := $(shell cat $(CHART)/Chart.yaml | yq '.version')

.PHONY: update
update:
	@echo -e "$(ATTN_COLOR)==> update $(CHART) $(NO_COLOR)"
	@helm dependency update $(CHART)

.PHONY: package
package:
	@echo -e "$(ATTN_COLOR)==> package $(CHART) $(NO_COLOR)"
	@mkdir -p $(CHART)/build
	@helm package $(CHART) -u -d $(CHART)/build

.PHONY: push
push:
	@echo -e "$(ATTN_COLOR)==> push $(CHART):$(CHART_VERSION) $(NO_COLOR)"
	@helm push $(CHART)/build/$(CHART)-$(CHART_VERSION).tgz $(CHART_REPO)

.PHONY: release
release: update package push
