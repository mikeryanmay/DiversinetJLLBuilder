# DiversinetJLLBuilder

[![Build JLL artifacts](https://github.com/mikeryanmay/DiversinetJLLBuilder/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/mikeryanmay/DiversinetJLLBuilder/actions/workflows/build.yml?query=branch%3Amain)

This repository owns the BinaryBuilder recipe and GitHub Actions workflow that
produce the generated
[Diversinet_jll](https://github.com/mikeryanmay/Diversinet_jll) package.

Each artifact contains both native libraries needed by
[Diversinet.jl](https://github.com/mikeryanmay/Diversinet.jl):

```text
libdiversinet
libjlDiversinetInterface
```

Ordinary Diversinet users do not need this repository. They install
`Diversinet.jl` through `DiversinetRegistry`, which resolves the published JLL.

## Source inputs

`build_tarballs.jl` uses immutable `GitSource` commits from the public
`Diversinet` and `Diversinet.jl` repositories. It does not read local source
checkouts or local source archives. Update both source commits when preparing
a release whose C++ core or CxxWrap bridge changed.

## Local build

Install Julia 1.12, start Docker, instantiate the builder environment, and run
the recipe:

```sh
cd /path/to/DiversinetJLLBuilder
julia --startup-file=no --project=. -e 'import Pkg; Pkg.instantiate()'
BINARYBUILDER_RUNNER=docker BINARYBUILDER_AUTOMATIC_APPLE=true julia --startup-file=no --project=. build_tarballs.jl --verbose
```

The generated binary tarballs are written to `products/`.

The current release targets Julia 1.12 on:

```text
aarch64-apple-darwin
aarch64-linux-gnu-libgfortran5-cxx11
x86_64-apple-darwin
x86_64-linux-gnu-libgfortran5-cxx11
```

The Linux targets are explicitly set to `libgfortran5`/`cxx11` so BinaryBuilder
uses a C++20-capable GCC toolchain.

The Apple targets use BinaryBuilder's clang/libc++ toolchain. The Linux targets
use GCC with the `cxx11` string ABI. Command-line programs and C++ tests are
disabled because the artifacts contain the reusable libraries only.

## Generate and test a local wrapper

After the product tarballs exist, generate the local wrapper package without
uploading anything:

```sh
BINARYBUILDER_AUTOMATIC_APPLE=true julia --startup-file=no --project=. build_tarballs.jl --skip-build --deploy=local --verbose
```

This writes the generated package to:

```text
~/.julia/dev/Diversinet_jll
```

Develop the generated JLL into a temporary Julia environment and verify both
libraries exist and load:

```sh
julia --startup-file=no --temp --project -e 'import Pkg; Pkg.develop(path=joinpath(homedir(), ".julia/dev/Diversinet_jll")); Pkg.instantiate(); using Libdl, Diversinet_jll; for library in (Diversinet_jll.libdiversinet, Diversinet_jll.libjlDiversinetInterface); @assert isfile(library); Libdl.dlclose(Libdl.dlopen(library)); end'
```

## Continuous integration and publication

Every push and pull request builds and audits all four targets, generates a
local JLL wrapper, and tests both libraries. These runs do not publish a
release.

To publish intentionally, run the **Build JLL artifacts** workflow manually
with its `publish` input enabled. Before dispatching it:

1. Update the immutable source commits in `build_tarballs.jl`.
2. Set `upstream_version` for a new upstream release.
3. Increment `DIVERSINET_JLL_VERSION` in the publication workflow. Build
   numbers use Julia's `MAJOR.MINOR.PATCH+N` convention and are never reused.
4. Let the ordinary CI build pass.
5. Dispatch publication and verify the generated `Diversinet_jll` release on
   all four operating-system/architecture combinations.

Publication requires the repository secret `JLL_DEPLOY_TOKEN`, with permission
to write the separate `Diversinet_jll` repository. Normal CI needs no deploy
credential.
