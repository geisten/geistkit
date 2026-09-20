# Lock: the only place versions live.
# The SHA is what gets built. The TAG is checked against it after fetch:
# a moved tag stops the build. TAG = - : upstream has no tag, or main moved past the last one.

# geistlib main (v0.11.0-78-g25861c0), not the v0.11.0 tag: the ASan, macOS-Intel, C++-header,
# AVX-512-dispatch and geist-memory fixes all landed after it, and the tag's tree even
# lacks tools/fetch-dep.sh. Tags here are cut by the release workflow, not by `git tag`,
# so a 0.11.1 release is a separate, deliberate step.
REPO_geistlib       := https://github.com/geisten/geistlib.git
TAG_geistlib        := -
SHA_geistlib        := 25861c0bd197f1a98f17e49efe0cdc48a0e40713

REPO_geistshell     := https://github.com/geisten/geistshell.git
TAG_geistshell      := -
SHA_geistshell      := 9e54cdd2fc4dfee521d4e5130c36df56fc0dac0e

REPO_geist-memory   := https://github.com/geisten/geist-memory.git
TAG_geist-memory    := -
SHA_geist-memory    := b29243de34aea856d42718eb63f2171ac9d8cadb

REPO_geist-diktat   := https://github.com/geisten/geist-diktat.git
TAG_geist-diktat    := -
SHA_geist-diktat    := 98525d23375c2df6084542112ab3f8107b1ca59a

# Engine revision each consumer is built against, cloned offline from build/deps/geistlib.
# Goal reached: every consumer uses SHA_geistlib, no consumer patches the engine, and
# geistshell (Makefile GEIST_REF) and geist-memory (mk/config.mk GEIST_REV) now pin this
# very revision upstream themselves — these lines confirm the pins instead of overriding them.
ENGINE_geistshell   := $(SHA_geistlib)
ENGINE_geist-memory := $(SHA_geistlib)
ENGINE_geist-diktat := $(SHA_geistlib)
