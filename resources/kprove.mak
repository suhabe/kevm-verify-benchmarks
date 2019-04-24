#
# Parameters
#

# path to a directory that contains .k.rev and .kevm.rev
BUILD_DIR?=../.build

K_REPO_URL?=https://github.com/kframework/k
KEVM_REPO_URL?=https://github.com/kframework/evm-semantics

ifndef SPEC_NAMES
$(error SPEC_NAMES is not set)
endif

SPEC_INI?=./spec.ini
LOCAL_LEMMAS?=../resources/abstract-semantics.k ../resources/verification.k \
                ../resources/evm-symbolic.k ../resources/ecrec-symbolic.k \
                ../resources/evm-data-symbolic.k \
                ../resources/edsl-static-array.k \
                ../resources/abstract-semantics-common.k
TMPLS?=../resources/module-tmpl.k ../resources/spec-tmpl.k
SPECS_DIR?=./generated-k

# additional options to kprove command
KPROVE_OPTS?=--smt-prelude ../resources/evm.smt2
KPROVE_OPTS+=$(EXT_KPROVE_OPTS)

# Define variable DEBUG to enable debug options below
#DEBUG=true
ifdef DEBUG
KPROVE_OPTS+=--debug-z3-queries --log-rules
endif

#
# Settings
#

# path to this file
THIS_FILE:=$(abspath $(lastword $(MAKEFILE_LIST)))
# path to root directory
ROOT:=$(abspath $(dir $(THIS_FILE))/../)

RESOURCES:=$(ROOT)/resources

K_VERSION   :=$(shell cat $(BUILD_DIR)/.k.rev)
KEVM_VERSION:=$(shell cat $(BUILD_DIR)/.kevm.rev)

K_REPO_DIR:=$(abspath $(BUILD_DIR)/k)
KEVM_REPO_DIR:=$(abspath $(BUILD_DIR)/evm-semantics)

K_BIN:=$(abspath $(K_REPO_DIR)/k-distribution/target/release/k/bin)

# For debug add: --log-rules --debug-z3-queries
KPROVE:=$(K_BIN)/kprove -v --debug -d $(KEVM_REPO_DIR)/.build/java -m VERIFICATION --z3-impl-timeout 500 \
        --deterministic-functions --no-exc-wrap \
        --cache-func-optimized --no-alpha-renaming --format-failures --boundary-cells k,pc \
        --log-cells k,output,statusCode,localMem,pc,gas,wordStack,callData,accounts,memoryUsed,\#pc,\#result \
        $(KPROVE_OPTS)

SPEC_FILES:=$(patsubst %,$(SPECS_DIR)/%-spec.k,$(SPEC_NAMES))

PANDOC_TANGLE_SUBMODULE:=$(ROOT)/.build/pandoc-tangle
TANGLER:=$(PANDOC_TANGLE_SUBMODULE)/tangle.lua
LUA_PATH:=$(PANDOC_TANGLE_SUBMODULE)/?.lua;;
export LUA_PATH

#
# Dependencies
#

.PHONY: all clean clean-deps deps split-proof-tests test

all: deps clean compile split-proof-tests test

compile:
	bash $(RESOURCES)/compile5

clean:
	rm -rf $(SPECS_DIR)

clean-deps:
	rm -rf $(SPECS_DIR) $(K_REPO_DIR) $(KEVM_REPO_DIR)

deps: $(K_REPO_DIR) $(KEVM_REPO_DIR) $(TANGLER)

$(K_REPO_DIR):
	git clone $(K_REPO_URL) $(K_REPO_DIR)
	cd $(K_REPO_DIR) \
		&& git reset --hard $(K_VERSION) \
		&& mvn package -DskipTests -Dllvm.backend.skip -Dhaskell.backend.skip

$(KEVM_REPO_DIR):
	git clone $(KEVM_REPO_URL) $(KEVM_REPO_DIR)
	cd $(KEVM_REPO_DIR) \
		&& git clean -fdx \
		&& git reset --hard $(KEVM_VERSION) \
		&& make tangle-deps \
		&& make defn \
		&& $(K_BIN)/kompile -v --debug --backend java -I .build/java -d .build/java --main-module ETHEREUM-SIMULATION --syntax-module ETHEREUM-SIMULATION .build/java/driver.k

$(TANGLER):
	git submodule update --init -- $(PANDOC_TANGLE_SUBMODULE)

#
# Specs
#

split-proof-tests: $(SPECS_DIR) $(SPECS_DIR)/lemmas.k $(SPEC_FILES)

$(SPECS_DIR): $(LOCAL_LEMMAS)
	mkdir -p $@
ifneq ($(strip $(LOCAL_LEMMAS)),)
	cp $(LOCAL_LEMMAS) $@
endif

ifneq ($(wildcard $(SPEC_INI:.ini=.md)),)
$(SPEC_INI): $(SPEC_INI:.ini=.md) $(TANGLER)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:".ini" $< > $@
endif

$(SPECS_DIR)/lemmas.k: $(RESOURCES)/lemmas.md $(TANGLER)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:".k" $< > $@

$(SPECS_DIR)/%-spec.k: $(TMPLS) $(SPEC_INI)
	python3 $(RESOURCES)/gen-spec.py $(TMPLS) $(SPEC_INI) $* $* > $@

#
# Kprove
#

test: $(addsuffix .test,$(SPEC_FILES))

$(SPECS_DIR)/%-spec.k.test: $(SPECS_DIR)/%-spec.k
	$(KPROVE) $<
