# geistkit — fetches the geisten building blocks at locked revisions and
# builds and verifies them offline.
#
#   make fetch    the only step with network: clones at the SHAs from versions.mk, checks tags
#   make verify   build, test, compare results against acceptance.tsv (natively, e.g. on macOS)
#   make ci       image + fetch, then verify inside the toolchain container WITHOUT network (Linux)
#
# Each consumer gets its engine from build/deps/geistlib (a local clone), at
# the revision given by ENGINE_<project>, never from the internet at its own pin.

include versions.mk

PROJECTS := geistlib geistshell geist-memory geist-diktat
DEPS     := $(CURDIR)/build/deps
ENGINE   := $(DEPS)/geistlib
# ponytail: fixed at 8. -j32 with ASan builds exhausted memory; raise it once the peak is measured.
JOBS     ?= 8
IMAGE    := geistkit-toolchain
RUN      := sh tools/run.sh

# Toolchain: gcc-14 as in the geisten CI, unless CC is given (macOS: clang or brew llvm@19).
# Static analysis needs clang: clang-19 in the container; set ANALYZE_CC natively.
ifeq ($(origin CC),default)
CC := gcc-14
endif
ANALYZE_CC ?= clang-19

.PHONY: fetch test verify selftest image ci clean FORCE $(addprefix test-,$(PROJECTS))

fetch: $(addprefix fetch-,$(PROJECTS))

# FORCE instead of .PHONY: make does not apply pattern rules to .PHONY targets.
# Nested repos are removed: `git clean` keeps them (geistshell deps/geist is even a tracked,
# orphaned gitlink) and a stale engine survives the pin. Everything under build/deps is disposable.
fetch-%: FORCE
	sh tools/fetch-dep.sh $* $(REPO_$*) $(SHA_$*)
	for d in $$(find build/deps/$* -mindepth 2 -name .git -prune); do rm -rf "$${d%/.git}"; done
	test '$(TAG_$*)' = - || test "$$(git -C build/deps/$* rev-parse '$(TAG_$*)^{commit}')" = $(SHA_$*)

test: $(addprefix test-,$(PROJECTS))

# Flags as in the respective upstream CI (.github/workflows/ci.yml). The build target
# (linux, pi5, mac, mac-omp) comes from each project's own detection.
test-geistlib:
	$(RUN) geistlib.unit     $(ENGINE) $(MAKE) -j$(JOBS) CC=$(CC) AUTO_FETCH_MODEL=0 test-unit
	$(RUN) geistlib.py       $(ENGINE) $(MAKE) test-py
	$(RUN) geistlib.contract $(ENGINE) $(MAKE) -j$(JOBS) CC=$(CC) agent-contract-smoke
	$(RUN) geistlib.asan     $(ENGINE) $(MAKE) -j$(JOBS) CC=$(CC) MODE=asan AUTO_FETCH_MODEL=0 test-unit

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
PROFILE ?= $(shell uname -s | tr A-Z a-z)-$(shell uname -m)$(AVX512)

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
	docker rm -f geistkit-ci >/dev/null 2>&1 || true
	docker run --rm --name geistkit-ci --network none --memory 24g --user $$(id -u):$$(id -g) -e HOME=/tmp \
		-v $(CURDIR):$(CURDIR) -w $(CURDIR) $(IMAGE) $(MAKE) verify JOBS=$(JOBS)

clean:
	rm -rf build
