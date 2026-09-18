# Lock: the only place versions live.
# The SHA is what gets built. The TAG is checked against it after fetch:
# a moved tag stops the build. TAG = - : upstream has no tag, or main moved past the last one.

# geistlib main (v0.11.0-64), not the v0.11.0 tag: the ASan, macOS-Intel, C++-header,
# AVX-512-dispatch and geist-memory fixes all landed after it, and the tag's tree even
# lacks tools/fetch-dep.sh. Tags here are cut by the release workflow, not by `git tag`,
# so a 0.11.1 release is a separate, deliberate step.
REPO_geistlib       := https://github.com/geisten/geistlib.git
TAG_geistlib        := -
SHA_geistlib        := 18a52c303421a4dd145002ac13c479bb77a8a900

REPO_geistshell     := https://github.com/geisten/geistshell.git
TAG_geistshell      := -
SHA_geistshell      := 4e97b60b10dabf47c2dafc952655e307be938688

REPO_geist-memory   := https://github.com/geisten/geist-memory.git
TAG_geist-memory    := -
SHA_geist-memory    := 3aa5fe10719debcdb12d6776eff0c6711c53226d

REPO_geist-diktat   := https://github.com/geisten/geist-diktat.git
TAG_geist-diktat    := -
SHA_geist-diktat    := 98525d23375c2df6084542112ab3f8107b1ca59a

# Engine revision each consumer is built against (cloned offline from
# build/deps/geistlib). Goal reached: every consumer uses SHA_geistlib.
# geist-memory still applies its own engine patch until its
# build/drop-engine-patch PR is merged; the patch now applies on top of this revision.
ENGINE_geistshell   := $(SHA_geistlib)
ENGINE_geist-memory := $(SHA_geistlib)
ENGINE_geist-diktat := $(SHA_geistlib)
