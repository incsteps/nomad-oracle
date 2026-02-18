STACK_NAME := nomad-nextflow
VERSION := 1.0.0
OUTPUT_FILE := $(STACK_NAME)-v$(VERSION).zip

INCLUDED_FILES := \
	*.tf \
	stack-manager.json \
	scripts/* \
	LICENSE \
	README.md

EXCLUDED_FILES := \
	".idea/*" \
	".terraform/*" \
	".git/*" \
	".DS_Store" \
	"terraform.tfvars" \
	"*.zip" \
	"*.tfstate*" \
	"*.key" \
	"nextflow/*" \
	"Makefile" \


# =================================================================
# Targets
# =================================================================

.PHONY: tf-init tf-apply tf-destroy oci-package oci-clean oci-all

tf-init:
	terraform init

tf-plan:
	terraform plan

tf-apply:
	terraform apply

tf-destroy:
	terraform destroy


oci-clean:
	@echo "-> Clean .zip files..."
	@rm -f *.zip
	@echo "✅ Done."

oci-package: oci-clean
	@echo "-> Create package: $(OUTPUT_FILE)"
	zip -r $(OUTPUT_FILE) . -x $(addprefix ,$(EXCLUDED_FILES))

	@echo "✅ Done"
	@ls -lh $(OUTPUT_FILE)

oci-all: oci-package
