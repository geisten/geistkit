# geistkit — fetches the geisten building blocks at locked revisions and
# builds and verifies them offline.
#
#   make fetch    the only step with network: clones at the SHAs from versions.mk, checks tags
#   make fetch-models  the other network step: the test models, via geistlib's pinned targets
#   make verify   build, test, compare results against acceptance.tsv (natively, e.g. on macOS)
#   make ci       image + fetch, then verify inside the toolchain container WITHOUT network (Linux)
#
# MODELS=1 adds the model-gated suites (geistlib test-int, test-e2e) and switches to the
# -model requirement profile. It needs `make fetch-models` first; nightly only.
#
# Each consumer gets its engine from build/deps/geistlib (a local clone), at
# the revision given by ENGINE_<project>, never from the internet at its own pin.

include versions.mk

PROJECTS := geistlib geistshell geist-memory geist-diktat
DEPS     := $(CURDIR)/build/deps
ENGINE   := $(DEPS)/geistlib
# ponytail: fixed at 8. -j32 with ASan builds exhausted memory; raise it once the peak is measured.
JOBS     ?= 8
# Container memory cap. Fits this desktop; a Raspberry Pi 5 has 4-16 GB, so the pi5 job lowers it.
MEMORY   ?= 24g
# Image tag and container name per working copy: a local run and a CI job on the same
# machine would otherwise overwrite each other's image and remove each other's container.
COPY_ID  := $(shell printf '%s' '$(CURDIR)' | cksum | cut -d' ' -f1)
IMAGE    := geistkit-toolchain-$(COPY_ID)
CONTAINER := geistkit-ci-$(COPY_ID)
RUN      := sh tools/run.sh
# Test models live OUTSIDE build/deps: fetch-dep.sh wipes each clone with `git clean -fdx`,
# which would delete gguf_artifacts/ on every fetch. MODELS=1 links them back in.
MODELS     ?= 0
MODELS_DIR := $(CURDIR)/build/models
# Throughput measurement (MODELS=1). BitNet activates no pass/fail test — it is geistlib's
# benchmark model — so this is where its numbers become data. Threads are pinned rather than
# left to the host: the figure has to be comparable between runs, and 4 also matches the
# hosted runners' vCPU count. Parameters otherwise as in geistlib's own cliff detector.
BENCH_MODEL    ?= bitnet-2b4t-i2_s.gguf
BENCH_THREADS  ?= 4
BENCH_REPEATS  ?= 10

# Toolchain: gcc-14 as in the geisten CI, unless CC is given (macOS: clang or brew llvm@19).
# Static analysis needs clang: clang-19 in the container; set ANALYZE_CC natively.
ifeq ($(origin CC),default)
CC := gcc-14
endif
ANALYZE_CC ?= clang-19

.PHONY: fetch fetch-models link-models test verify selftest image ci clean FORCE $(addprefix test-,$(PROJECTS))

fetch: $(addprefix fetch-,$(PROJECTS))

# FORCE instead of .PHONY: make does not apply pattern rules to .PHONY targets.
# Nested repos are removed: `git clean` keeps them (geistshell deps/geist is even a tracked,
# orphaned gitlink) and a stale engine survives the pin. Everything under build/deps is disposable.
fetch-%: FORCE
	sh tools/fetch-dep.sh $* $(REPO_$*) $(SHA_$*)
	for d in $$(find build/deps/$* -mindepth 2 -name .git -prune); do rm -rf "$${d%/.git}"; done
	test '$(TAG_$*)' = - || test "$$(git -C build/deps/$* rev-parse '$(TAG_$*)^{commit}')" = $(SHA_$*)

# geistlib owns the model pins (fixed HF revision + SHA-256, PR #413), so we call its targets
# instead of repeating URLs or checksums here. Network step, never part of verify.
fetch-models: fetch-geistlib
	$(MAKE) -C $(ENGINE) fetch-qwen35-model fetch-bench-model
	mkdir -p $(MODELS_DIR)
	ln -f $(ENGINE)/gguf_artifacts/*.gguf $(MODELS_DIR)/

# Offline: hardlink the kept models back into the freshly fetched clone. Each geistlib test
# picks the fixture it needs by name from gguf_artifacts/ — forcing GEIST_GGUF_PATH instead
# hands Gemma-specific tests a foreign model and makes them fail rather than skip.
link-models:
	@ls $(MODELS_DIR)/*.gguf >/dev/null 2>&1 || { echo "no models in $(MODELS_DIR): run make fetch-models"; exit 1; }
	mkdir -p $(ENGINE)/gguf_artifacts
	ln -f $(MODELS_DIR)/*.gguf $(ENGINE)/gguf_artifacts/

test: $(addprefix test-,$(PROJECTS))

# Flags as in the respective upstream CI (.github/workflows/ci.yml). The build target
# (linux, pi5, mac, mac-omp) comes from each project's own detection.
test-geistlib: $(if $(filter 1,$(MODELS)),link-models)
	$(RUN) geistlib.unit     $(ENGINE) $(MAKE) -j$(JOBS) CC=$(CC) AUTO_FETCH_MODEL=0 test-unit
	$(RUN) geistlib.py       $(ENGINE) $(MAKE) test-py
	$(RUN) geistlib.contract $(ENGINE) $(MAKE) -j$(JOBS) CC=$(CC) agent-contract-smoke
	$(RUN) geistlib.asan     $(ENGINE) $(MAKE) -j$(JOBS) CC=$(CC) MODE=asan AUTO_FETCH_MODEL=0 test-unit
ifeq ($(MODELS),1)
	$(RUN) geistlib.int      $(ENGINE) $(MAKE) -j$(JOBS) CC=$(CC) AUTO_FETCH_MODEL=0 test-int
	$(RUN) geistlib.e2e      $(ENGINE) $(MAKE) -j$(JOBS) CC=$(CC) AUTO_FETCH_MODEL=0 test-e2e
	$(RUN) geistlib.bench    $(ENGINE) sh -c 'set -e; T=$$(sh mk/detect-target.sh); $(MAKE) -j$(JOBS) CC=$(CC) TARGET=$$T bin/$$T/release/tests/bench_perf_sweep; OMP_NUM_THREADS=$(BENCH_THREADS) bin/$$T/release/tests/bench_perf_sweep --gguf gguf_artifacts/$(BENCH_MODEL) --seq-lens 128 --decode-n 16 --warmup 4 --repeats $(BENCH_REPEATS) --threads $(BENCH_THREADS)'
endif

SHELL_MAKE = $(MAKE) HOST_CC=$(CC) GEIST_REPO=$(ENGINE) GEIST_REF=$(ENGINE_geistshell)
# sync-engine as a separate step: under -j, objects compile before the clone lands (geist.h missing).
test-geistshell:
	$(RUN) geistshell.engine   $(DEPS)/geistshell $(SHELL_MAKE) sync-engine
	$(RUN) geistshell.build    $(DEPS)/geistshell $(SHELL_MAKE) -j$(JOBS)
	$(RUN) geistshell.test     $(DEPS)/geistshell $(SHELL_MAKE) test
	$(RUN) geistshell.baseline $(DEPS)/geistshell env SPG_BIN=build/host-debug/bin/geistshell sh test/test_cli_baseline.sh

# deps and check-repro without -j: both race under -j (check-engine before the stamp; check-repro.sh inherits MAKEFLAGS).
MEMORY_MAKE = $(MAKE) CC=$(CC) GEIST_REPO=$(ENGINE) GEIST_REV=$(ENGINE_geist-memory)
# test-model-alloc/test-tokenizer-oom link with GNU ld --wrap; Apple ld has none. geist-memory's own macOS CI omits them too.
MEMORY_ASAN := check fuzz $(if $(filter Darwin,$(shell uname -s)),,test-model-alloc test-tokenizer-oom)
test-geist-memory:
	$(RUN) geist-memory.deps    $(DEPS)/geist-memory $(MEMORY_MAKE) deps check-deps
	$(RUN) geist-memory.check   $(DEPS)/geist-memory $(MEMORY_MAKE) -j$(JOBS) check
	$(RUN) geist-memory.asan    $(DEPS)/geist-memory $(MEMORY_MAKE) -j$(JOBS) MODE=asan $(MEMORY_ASAN)
	$(RUN) geist-memory.install $(DEPS)/geist-memory $(MEMORY_MAKE) -j$(JOBS) check-linkage check-install example
	$(RUN) geist-memory.repro   $(DEPS)/geist-memory $(MEMORY_MAKE) check-repro
	$(RUN) geist-memory.analyze $(DEPS)/geist-memory $(MEMORY_MAKE) -j$(JOBS) CC=$(ANALYZE_CC) analyze

DIKTAT_MAKE = $(MAKE) CC=$(CC) GEIST_REPO=$(ENGINE) GEIST_REF=$(ENGINE_geist-diktat)
test-geist-diktat:
	$(RUN) geist-diktat.build $(DEPS)/geist-diktat $(DIKTAT_MAKE) -j$(JOBS)
	$(RUN) geist-diktat.test  $(DEPS)/geist-diktat $(DIKTAT_MAKE) test
	$(RUN) geist-diktat.audit $(DEPS)/geist-diktat $(DIKTAT_MAKE) test-audit

selftest:
	sh test/verify_test.sh

# Counts depend on the platform, so requirements are acceptance.tsv (all platforms) plus
# acceptance.d/$(PROFILE).tsv. Profile = os-arch, plus -avx512 where geistlib's AVX-512
# kernels can run (F/BW/DQ/VL; test_q4kx8_gemm_unit skips otherwise). No profile file, no pass.
AVX512  := $(shell for f in avx512f avx512bw avx512dq avx512vl; do grep -qw $$f /proc/cpuinfo 2>/dev/null || exit 1; done && echo -avx512)
# MODELS=1 gets its own profile, so the model run can never be judged against model-free counts.
PROFILE ?= $(shell uname -s | tr A-Z a-z)-$(shell uname -m)$(AVX512)$(if $(filter 1,$(MODELS)),-model)

verify: selftest
	@test -f acceptance.d/$(PROFILE).tsv || { echo "no requirements for profile $(PROFILE): acceptance.d/$(PROFILE).tsv missing"; exit 1; }
	rm -rf build/results build/logs
	mkdir -p build
	{ echo "profile $(PROFILE)"; uname -a; $(CC) --version; $(ANALYZE_CC) --version; cat /toolchain.txt 2>/dev/null; } >build/toolchain.txt 2>&1 || true
	$(MAKE) test
	cat build/results/*.tsv >build/results.tsv
	cat acceptance.tsv acceptance.d/$(PROFILE).tsv >build/acceptance.tsv
	{ echo "profile $(PROFILE)"; sh tools/verify.sh build/results.tsv build/acceptance.tsv; } >build/verify.txt; rc=$$?; cat build/verify.txt; exit $$rc

image:
	docker build -t $(IMAGE) .

# Same path inside the container, so the absolute ENGINE paths match.
# Fixed name: a killed docker client leaves the container running; the next run removes it first.
ci: image fetch
	docker rm -f $(CONTAINER) >/dev/null 2>&1 || true
	docker run --rm --name $(CONTAINER) --network none --memory $(MEMORY) --user $$(id -u):$$(id -g) -e HOME=/tmp \
		-v $(CURDIR):$(CURDIR) -w $(CURDIR) $(IMAGE) $(MAKE) verify JOBS=$(JOBS) CC=$(CC) ANALYZE_CC=$(ANALYZE_CC) MODELS=$(MODELS)

clean:
	rm -rf build
