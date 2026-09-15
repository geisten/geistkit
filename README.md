# geistkit

Reproducible build and verification of the [geisten](https://github.com/geisten)
building blocks: geistlib, geistshell, geist-memory, geist-diktat.

geistkit contains no source code of those projects, no patches and no models.
It holds only the recipe (which revision, which toolchain) and the check
(which results are required).

```sh
make ci        # from scratch: toolchain image, fetch, build + test offline, compare
```

- `versions.mk`: the lock. Every project is pinned to a commit SHA; tags are checked against it.
- `Dockerfile`: the toolchain of the geisten CI (ubuntu 24.04 frozen by digest, gcc-14, clang-19).
- `make fetch` is the only step with network. Build and tests run in the container with `--network none`.
- `acceptance.tsv`: the requirements. A missing measured value fails. So does any
  non-zero exit that no requirement covers. Known defects are not tolerated: the
  gate stays red until the fix has landed upstream.
- Results: `build/verify.txt`, `build/results.tsv`, logs in `build/logs/`.

Fixes are made through pull requests in the original repositories, never as
patches here. Plan and status: [TODO.md](TODO.md) (German).

License: Apache-2.0
