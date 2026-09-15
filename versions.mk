# Lock: the only place versions live.
# The SHA is what gets built. The TAG is checked against it after fetch:
# a moved tag stops the build. TAG = - : upstream has no tag yet.

REPO_geistlib       := https://github.com/geisten/geistlib.git
TAG_geistlib        := v0.11.0
SHA_geistlib        := 6781d425e4d9ac9ec4bf5fa7da9fa383be7e5d58

REPO_geistshell     := https://github.com/geisten/geistshell.git
TAG_geistshell      := -
SHA_geistshell      := 162c49b624ce490098e716bdc432d965e4bb3f17

REPO_geist-memory   := https://github.com/geisten/geist-memory.git
TAG_geist-memory    := -
SHA_geist-memory    := 3aa5fe10719debcdb12d6776eff0c6711c53226d

REPO_geist-diktat   := https://github.com/geisten/geist-diktat.git
TAG_geist-diktat    := v0.2.0
SHA_geist-diktat    := e97675cd33775f19bcd6b437b194bbfce741692f

# Engine revision each consumer is built against (cloned offline from
# build/deps/geistlib). Goal: all equal to SHA_geistlib. Any deviation is debt
# and belongs in TODO.md.
# geistshell: v0.10.1. With v0.11.0 geist_session_peek_logits breaks the build (model_adapter.c:326/733).
ENGINE_geistshell   := 10d4fe75648fee7b8002983df8db0fa2c141eaa1
# geist-memory: its own pin (v0.11.0-22). v0.11.0 builds and tests green, but check-deps
# needs tools/fetch-dep.sh in the engine, which only lands after v0.11.0.
ENGINE_geist-memory := b78df97fdb09b937f07082533e970b2d7a16ce83
ENGINE_geist-diktat := $(SHA_geistlib)
