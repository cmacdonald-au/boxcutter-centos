# if Makefile.local exists, include it
ifneq ("$(wildcard Makefile.local)", "")
	include Makefile.local
endif

PACKER ?= packer
PACKER_DEBUG ?= 

# Possible values for CM: (nocm | chef | chefdk | salt | puppet)
CM ?= nocm
# Possible values for CM_VERSION: (latest | x.y.z | x.y)
CM_VERSION ?=
ifndef CM_VERSION
	ifneq ($(CM),nocm)
		CM_VERSION = latest
	endif
endif

#if you override these in Makefile.local or run `make clean` - you must run `make kickstart` to update the kickstart files
SSH_USERNAME ?= vagrant
SSH_PASSWORD ?= vagrant
ROOT_PASSWORD ?= $(SSH_PASSWORD)

INSTALL_SSH_KEY ?= true
# https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
SSH_KEY ?= ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key

ISO_PATH ?= iso
BOX_VERSION ?= $(shell cat VERSION)
ifeq ($(CM),nocm)
	BOX_SUFFIX := -$(CM)-$(BOX_VERSION).box
else
	BOX_SUFFIX := -$(CM)$(CM_VERSION)-$(BOX_VERSION).box
endif

# Packer does not allow empty variables, so only pass variables that are defined
PACKER_VARS_LIST = 'cm=$(CM)' 'headless=$(HEADLESS)' 'update=$(UPDATE)' 'version=$(BOX_VERSION)' 'ssh_username=$(SSH_USERNAME)' 'ssh_password=$(SSH_PASSWORD)' 'install_ssh_key=$(INSTALL_SSH_KEY)' 'iso_path=$(ISO_PATH)'
ifdef CM_VERSION
	PACKER_VARS_LIST += 'cm_version=$(CM_VERSION)'
endif
PACKER_VARS := $(addprefix -var , $(PACKER_VARS_LIST))

KICKSTART_ARGS = SSH_PASSWORD=$(SSH_PASSWORD) SSH_USERNAME=$(SSH_USERNAME) ROOT_PASSWORD=$(ROOT_PASSWORD)

# This comes after the addprefix step because SSH pubkey lines have spaces in them, eg: `ssh-rsa AAAAB....` (but they don't have single quotes)
ifdef SSH_KEY
	ifeq ($(INSTALL_SSH_KEY),true)
		PACKER_VARS += -var 'ssh_key=$(SSH_KEY)'
	endif
endif

ifdef PACKER_DEBUG
	PACKER_CMD := PACKER_LOG=1 $(PACKER)
	PACKER_DEBUG := -debug
else
	PACKER_CMD := $(PACKER)
endif

BUILDER_TYPES := vmware virtualbox parallels
TEMPLATE_FILENAMES := $(wildcard *.json)
KICKSTART_DIR := http
KICKSTART_TEMPLATES := $(wildcard $(KICKSTART_DIR)/*.tpl)
KICKSTART_FILENAMES := $(wildcard $(KICKSTART_DIR)/*.cfg)
BOX_FILENAMES := $(TEMPLATE_FILENAMES:.json=$(BOX_SUFFIX))
TEST_BOX_FILES := $(foreach builder, $(BUILDER_TYPES), $(foreach box_filename, $(BOX_FILENAMES), test-box/$(builder)/$(box_filename)))
VMWARE_BOX_DIR := box/vmware
VIRTUALBOX_BOX_DIR := box/virtualbox
PARALLELS_BOX_DIR := box/parallels
VMWARE_BOX_FILES := $(foreach box_filename, $(BOX_FILENAMES), $(VMWARE_BOX_DIR)/$(box_filename))
VIRTUALBOX_BOX_FILES := $(foreach box_filename, $(BOX_FILENAMES), $(VIRTUALBOX_BOX_DIR)/$(box_filename))
PARALLELS_TEMPLATE_FILENAMES := $(TEMPLATE_FILENAMES)
PARALLELS_BOX_FILENAMES := $(PARALLELS_TEMPLATE_FILENAMES:.json=$(BOX_SUFFIX))
PARALLELS_BOX_FILES := $(foreach box_filename, $(PARALLELS_BOX_FILENAMES), box/parallels/$(box_filename))
BOX_FILES := $(VMWARE_BOX_FILES) $(VIRTUALBOX_BOX_FILES) $(PARALLELS_BOX_FILES)
VMWARE_OUTPUT := output-vmware-iso
VIRTUALBOX_OUTPUT := output-virtualbox-iso
PARALLELS_OUTPUT := output-parallels-iso
VMWARE_BUILDER := vmware-iso
VIRTUALBOX_BUILDER := virtualbox-iso
PARALLELS_BUILDER := parallels-iso
CURRENT_DIR = $(shell pwd)
SOURCES := $(wildcard script/*.sh)

.PHONY: list

all: $(BOX_FILES)

test: $(TEST_BOX_FILES)

###############################################################################
# Target shortcuts
define SHORTCUT

vmware/$(1): $(VMWARE_BOX_DIR)/$(1)$(BOX_SUFFIX)

test-vmware/$(1): test-$(VMWARE_BOX_DIR)/$(1)$(BOX_SUFFIX)

ssh-vmware/$(1): ssh-$(VMWARE_BOX_DIR)/$(1)$(BOX_SUFFIX)

virtualbox/$(1): $(VIRTUALBOX_BOX_DIR)/$(1)$(BOX_SUFFIX)

test-virtualbox/$(1): test-$(VIRTUALBOX_BOX_DIR)/$(1)$(BOX_SUFFIX)

ssh-virtualbox/$(1): ssh-$(VIRTUALBOX_BOX_DIR)/$(1)$(BOX_SUFFIX)

parallels/$(1): $(PARALLELS_BOX_DIR)/$(1)$(BOX_SUFFIX)

test-parallels/$(1): test-$(PARALLELS_BOX_DIR)/$(1)$(BOX_SUFFIX)

ssh-parallels/$(1): ssh-$(PARALLELS_BOX_DIR)/$(1)$(BOX_SUFFIX)

$(1): vmware/$(1) virtualbox/$(1) parallels/$(1)

test-$(1): test-vmware/$(1) test-virtualbox/$(1) test-parallels/$(1)

s3cp-$(1): s3cp-$(VMWARE_BOX_DIR)/$(1)$(BOX_SUFFIX) s3cp-$(VIRTUALBOX_BOX_DIR)/$(1)$(BOX_SUFFIX) s3cp-$(PARALLELS_BOX_DIR)/$(1)$(BOX_SUFFIX)

s3cp-vmware/$(1): s3cp-$(VMWARE_BOX_DIR)/$(1)$(BOX_SUFFIX)

s3cp-virtualbox/$(1): s3cp-$(VIRTUALBOX_BOX_DIR)/$(1)$(BOX_SUFFIX)

s3cp-parallels/$(1): s3cp-$(PARALLELS_BOX_DIR)/$(1)$(BOX_SUFFIX)

test-atlas-$(1): test-atlas-$(VMWARE_BOX_DIR)/$(1)$(BOX_SUFFIX) test-atlas-$(VIRTUALBOX_BOX_DIR)/$(1)$(BOX_SUFFIX) test-atlas-$(PARALLELS_BOX_DIR)/$(1)$(BOX_SUFFIX)

test-atlas-vmware/$(1): test-atlas-$(VMWARE_BOX_DIR)/$(1)$(BOX_SUFFIX)

test-atlas-virtualbox/$(1): test-atlas-$(VIRTUALBOX_BOX_DIR)/$(1)$(BOX_SUFFIX)

test-atlas-parallels/$(1): test-atlas-$(PARALLELS_BOX_DIR)/$(1)$(BOX_SUFFIX)

s3cp-$(1): s3cp-$(VMWARE_BOX_DIR)/$(1)$(BOX_SUFFIX) s3cp-$(VIRTUALBOX_BOX_DIR)/$(1)$(BOX_SUFFIX) s3cp-$(PARALLELS_BOX_DIR)/$(1)$(BOX_SUFFIX)

register-atlas-$(1): register-atlas/$(1)$(BOX_SUFFIX)

endef

SHORTCUT_TARGETS := $(basename $(TEMPLATE_FILENAMES))
$(foreach i,$(SHORTCUT_TARGETS),$(eval $(call SHORTCUT,$(i))))
###############################################################################

$(VMWARE_BOX_DIR)/%$(BOX_SUFFIX): %.json $(SOURCES)
	rm -rf $(VMWARE_OUTPUT)
	mkdir -p $(VMWARE_BOX_DIR)
	$(PACKER_CMD) build $(PACKER_DEBUG) -only=$(VMWARE_BUILDER) $(PACKER_VARS) $<

$(VIRTUALBOX_BOX_DIR)/%$(BOX_SUFFIX): %.json $(SOURCES)
	rm -rf $(VIRTUALBOX_OUTPUT)
	mkdir -p $(VIRTUALBOX_BOX_DIR)
	$(PACKER_CMD) build $(PACKER_DEBUG) -only=$(VIRTUALBOX_BUILDER) $(PACKER_VARS) $<

$(PARALLELS_BOX_DIR)/%$(BOX_SUFFIX): %.json $(SOURCES)
	rm -rf $(PARALLELS_OUTPUT)
	mkdir -p $(PARALLELS_BOX_DIR)
	$(PACKER_CMD) build $(PACKER_DEBUG) -only=$(PARALLELS_BUILDER) $(PACKER_VARS) $<

list:
	@echo "Prepend 'vmware/', 'virtualbox/', or 'parallels/' to build only one target platform:"
	@echo "  make vmware/centos66"
	@echo ""
	@echo "Targets:"
	@for shortcut_target in $(SHORTCUT_TARGETS) ; do \
		echo $$shortcut_target ; \
	done

validate:
	@for template_filename in $(TEMPLATE_FILENAMES) ; do \
		echo Checking $$template_filename ; \
		packer validate $$template_filename ; \
	done

kickstart: clean-kickstart
	@echo Creating kickstart config files using $(KICKSTART_ARGS)
	@for kstpl_filename in $(KICKSTART_TEMPLATES) ; do \
		echo "=> Input: $$kstpl_filename" ; \
		env $(KICKSTART_ARGS) bin/kickstart.sh $$kstpl_filename ; \
	done

clean: clean-builders clean-output clean-packer-cache clean-kickstart

clean-builders:
	@for builder in $(BUILDER_TYPES) ; do \
		if test -d box/$$builder ; then \
			echo Deleting box/$$builder/*.box ; \
			find box/$$builder -maxdepth 1 -type f -name "*.box" ! -name .gitignore -exec rm '{}' \; ; \
		fi ; \
	done

clean-output:
	@for builder in $(BUILDER_TYPES) ; do \
		echo Deleting output-$$builder-iso ; \
		echo rm -rf output-$$builder-iso ; \
	done

clean-packer-cache:
	echo Deleting packer_cache
	rm -rf packer_cache

clean-kickstart:
	@echo Cleaning out old kickstart config files
	@for kickstart_filename in $(KICKSTART_FILENAMES) ; do \
		echo "=> $$kickstart_filename" ; \
		rm -f $$kickstart_filename ; \
	done

test-vmware: $(addprefix test-,$(VMWARE_BOX_FILES))
test-virtualbox: $(addprefix test-,$(VIRTUALBOX_BOX_FILES))
test-parallels: $(addprefix test-,$(PARALLELS_BOX_FILES))

test-$(VMWARE_BOX_DIR)/%$(BOX_SUFFIX): $(VMWARE_BOX_DIR)/%$(BOX_SUFFIX)
	bin/test-box.sh $< vmware_desktop vmware_fusion $(CURRENT_DIR)/test/*_spec.rb || exit

test-$(VIRTUALBOX_BOX_DIR)/%$(BOX_SUFFIX): $(VIRTUALBOX_BOX_DIR)/%$(BOX_SUFFIX)
	bin/test-box.sh $< virtualbox virtualbox $(CURRENT_DIR)/test/*_spec.rb || exit

test-$(PARALLELS_BOX_DIR)/%$(BOX_SUFFIX): $(PARALLELS_BOX_DIR)/%$(BOX_SUFFIX)
	bin/test-box.sh $< parallels parallels $(CURRENT_DIR)/test/*_spec.rb || exit

ssh-$(VMWARE_BOX_DIR)/%$(BOX_SUFFIX): $(VMWARE_BOX_DIR)/%$(BOX_SUFFIX)
	bin/ssh-box.sh $< vmware_desktop vmware_fusion $(CURRENT_DIR)/test/*_spec.rb

ssh-$(VIRTUALBOX_BOX_DIR)/%$(BOX_SUFFIX): $(VIRTUALBOX_BOX_DIR)/%$(BOX_SUFFIX)
	bin/ssh-box.sh $< virtualbox virtualbox $(CURRENT_DIR)/test/*_spec.rb

ssh-$(PARALLELS_BOX_DIR)/%$(BOX_SUFFIX): $(PARALLELS_BOX_DIR)/%$(BOX_SUFFIX)
	bin/ssh-box.sh $< parallels parallels $(CURRENT_DIR)/test/*_spec.rb

S3_STORAGE_CLASS ?= REDUCED_REDUNDANCY
S3_ALLUSERS_ID ?= uri=http://acs.amazonaws.com/groups/global/AllUsers

s3cp-$(VMWARE_BOX_DIR)/%$(BOX_SUFFIX): $(VMWARE_BOX_DIR)/%$(BOX_SUFFIX)
	@for i in {1..20}; do \
		aws --profile $(AWS_PROFILE) s3 cp $< $(VMWARE_S3_BUCKET) --storage-class $(S3_STORAGE_CLASS) --grants full=$(S3_GRANT_ID) read=$(S3_ALLUSERS_ID) && break || sleep 62; \
	done

s3cp-$(VIRTUALBOX_BOX_DIR)/%$(BOX_SUFFIX): $(VIRTUALBOX_BOX_DIR)/%$(BOX_SUFFIX)
	@for i in {1..20}; do \
		aws --profile $(AWS_PROFILE) s3 cp $< $(VIRTUALBOX_S3_BUCKET) --storage-class $(S3_STORAGE_CLASS) --grants full=$(S3_GRANT_ID) read=$(S3_ALLUSERS_ID) && break || sleep 62; \
	done

s3cp-$(PARALLELS_BOX_DIR)/%$(BOX_SUFFIX): $(PARALLELS_BOX_DIR)/%$(BOX_SUFFIX)
	@for i in {1..20}; do \
		aws --profile $(AWS_PROFILE) s3 cp $< $(PARALLELS_S3_BUCKET) --storage-class $(S3_STORAGE_CLASS) --grants full=$(S3_GRANT_ID) read=$(S3_ALLUSERS_ID) && break || sleep 62; \
	done

s3cp-vmware: $(addprefix s3cp-,$(VMWARE_BOX_FILES))
s3cp-virtualbox: $(addprefix s3cp-,$(VIRTUALBOX_BOX_FILES))
s3cp-parallels: $(addprefix s3cp-,$(PARALLELS_BOX_FILES))

ATLAS_NAME ?= boxcutter

test-atlas: test-atlas-vmware test-atlas-virtualbox test-atlas-parallels
test-atlas-vmware: $(addprefix test-atlas-,$(VMWARE_BOX_FILES))
test-atlas-virtualbox: $(addprefix test-atlas-,$(VIRTUALBOX_BOX_FILES))
test-atlas-parallels: $(addprefix test-atlas-,$(PARALLELS_BOX_FILES))

test-atlas-$(VMWARE_BOX_DIR)%$(BOX_SUFFIX):
	bin/test-vagrantcloud-box.sh boxcutter$* vmware_fusion vmware_desktop $(CURRENT_DIR)/test/*_spec.rb
	bin/test-vagrantcloud-box.sh box-cutter$* vmware_fusion vmware_desktop $(CURRENT_DIR)/test/*_spec.rb

test-atlas-$(VIRTUALBOX_BOX_DIR)%$(BOX_SUFFIX):
	bin/test-vagrantcloud-box.sh boxcutter$* virtualbox virtualbox $(CURRENT_DIR)/test/*_spec.rb
	bin/test-vagrantcloud-box.sh box-cutter$* virtualbox virtualbox $(CURRENT_DIR)/test/*_spec.rb

test-atlas-$(PARALLELS_BOX_DIR)%$(BOX_SUFFIX):
	bin/test-vagrantcloud-box.sh boxcutter$* parallels parallels $(CURRENT_DIR)/test/*_spec.rb
	bin/test-vagrantcloud-box.sh box-cutter$* parallels parallels $(CURRENT_DIR)/test/*_spec.rb

register-atlas: $(addprefix register-atlas-,$(basename $(TEMPLATE_FILENAMES)))

register-atlas/%$(BOX_SUFFIX):
	bin/register_atlas.sh $* $(BOX_SUFFIX) $(BOX_VERSION)
	bin/register_atlas_box_cutter.sh $* $(BOX_SUFFIX) $(BOX_VERSION)
