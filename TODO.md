# Diversinet_jll TODO

Checklist for creating a Julia binary wrapper package for the native
`Diversinet` C++ library.

## Goal

Make the ordinary Julia install path avoid local `phyloploid_lib` checkouts,
manual Meson builds, and `DIVERSINET_CPP_ROOT`:

```julia
Pkg.add("Diversinet")
using Diversinet
```

## Current Scope

Start with a core-only JLL:

```text
Diversinet_jll provides libdiversinet
Diversinet.jl builds/loads its CxxWrap bridge separately
```

Keep `libjlDiversinetInterface` out of the JLL for now. The CxxWrap bridge is
more sensitive to Julia/CxxWrap ABI details, so the first stable target is just
the core C++ library.

## Current Status

- [x] Created a local BinaryBuilder recipe in `build_tarballs.jl`.
- [x] Created a local source archive at
      `sources/phyloploid_lib-local.tar.gz`.
- [x] Generated a local JLL wrapper package at:

  ```text
  /Users/mike/.julia/dev/Diversinet_jll
  ```

- [x] Built tarballs successfully:

  ```text
  products/Diversinet.v0.0.1.aarch64-apple-darwin.tar.gz
  products/Diversinet.v0.0.1.aarch64-linux-gnu-libgfortran5-cxx11.tar.gz
  products/Diversinet.v0.0.1.x86_64-linux-gnu-libgfortran5-cxx11.tar.gz
  ```

- [x] Confirmed the recipe builds only one Meson target:

  ```text
  libdiversinet
  ```

- [x] Confirmed the JLL build disables command-line programs and tests:

  ```sh
  -Dprograms=false
  -Dtests=false
  ```

- [x] Latest successful product hashes:

  ```text
  aarch64-apple-darwin
  SHA256: 63f1fbc395e0fac49340d8e27ec35df51ebb8cb68f4bfa1061e06aa9c68cd21a
  Tree hash: 8d815a9646d1544826e973abeb74f5d1bca476a6

  aarch64-linux-gnu-libgfortran5-cxx11
  SHA256: 4ded57e69579d220722df4e907f39c79a5a5c96d5d1597da4f26592cb6a12592
  Tree hash: 4ffe29bdb66f1f4e4798c1a9865d69a485663de0

  x86_64-linux-gnu-libgfortran5-cxx11
  SHA256: e4690bcc4cff1b9bd269f99891cf542f2ea13ee06240bdb3a515c0fc0bfa745c
  Tree hash: 9f5be29ae53cd444492f4ecbcef06f85e0ecab9a
  ```

## Known Build Warnings

- [ ] Install a license file into:

  ```text
  ${prefix}/share/licenses/Diversinet
  ```

  BinaryBuilder currently reports this as an audit error, but still packages the
  tarball.

- [x] Rebuilt the macOS artifact with clang/libc++ instead of GCC/libstdc++.

  ```text
  /usr/lib/libc++.1.dylib
  ```

  Verified with `otool -L` and `nm`: the artifact no longer links to
  `libstdc++.6.dylib`, and exported `std::string` symbols use the macOS
  `std::__1` ABI.

- [ ] Investigate the Linux audit warning:

  ```text
  Linked library libgcc_s.so.1 could not be resolved and could not be auto-mapped
  ```

  The Linux builds complete anyway, but this should be understood before
  treating the JLL as release-ready.

- [ ] Consider cleaning Apple extended attributes from the local archive. The
      current tarball extracts successfully, but BinaryBuilder prints
      `LIBARCHIVE.xattr...` warnings.

## phyloploid_lib Requirements

- [x] `phyloploid_lib` builds with Meson.
- [x] `phyloploid_lib` installs:

  ```text
  $prefix/lib/libdiversinet.*
  $prefix/include/DiversinetInterface.h
  $prefix/lib/pkgconfig/diversinet.pc
  ```

- [x] Added Meson options so JLL builds can skip non-library targets:

  ```text
  programs
  tests
  ```

- [x] Disabled `DenseRungeKuttaDOPRI5` for now.
- [x] Replaced unfinished dense error functors with explicit runtime errors.
- [x] Fixed the Boost.Odeint resizeability trait for `EigenState`.

## BinaryBuilder Recipe

- [x] Use local archive source for initial testing.
- [ ] Replace local archive source with a reproducible upstream source:

  - [ ] tagged GitHub release tarball
  - [ ] git tree URL/commit

- [x] Declare product:

  ```julia
  LibraryProduct("libdiversinet", :libdiversinet)
  ```

- [x] Declare dependencies:

  ```julia
  Dependency("boost_jll")
  Dependency("Eigen_jll")
  HostBuildDependency("Ninja_jll")
  ```

- [x] Build macOS manually with BinaryBuilder's clang toolchain to avoid the
      GCC/libstdc++ ABI mismatch:

  ```sh
  "${target}-clang++" -std=c++20 ...
  ```

- [x] Use BinaryBuilder's GCC Meson cross file for Linux:

  ```sh
  --cross-file="${MESON_TARGET_TOOLCHAIN%.*}_gcc.meson"
  ```

- [x] Force Linux targets to `libgfortran5`/`cxx11` so BinaryBuilder uses a
      C++20-capable GCC toolchain:

  ```julia
  Platform("x86_64", "linux"; libc = "glibc", cxxstring_abi = "cxx11", libgfortran_version = v"5.0.0")
  Platform("aarch64", "linux"; libc = "glibc", cxxstring_abi = "cxx11", libgfortran_version = v"5.0.0")
  ```

## Platform Builds

- [x] macOS aarch64
- [x] Linux x86_64, glibc, libgfortran5, cxx11
- [x] Linux aarch64, glibc, libgfortran5, cxx11
- [ ] macOS x86_64
- [ ] Windows, defer unless needed

## Generated JLL Package

- [x] Generate the actual `Diversinet_jll` wrapper package.
- [x] Verify the generated package exports:

  ```julia
  using Diversinet_jll
  Diversinet_jll.libdiversinet
  ```

- [x] Verify the artifact contains `libdiversinet`.
- [x] Verify the library can be loaded with `Libdl.dlopen`.

  Verified locally with:

  ```sh
  julia --project=. -e 'using Libdl, Diversinet_jll; h = Libdl.dlopen(Diversinet_jll.libdiversinet); println(h != C_NULL); Libdl.dlclose(h)'
  ```

- [x] Verify the regenerated local wrapper points to the rebuilt macOS artifact:

  ```text
  /Users/mike/.julia/artifacts/8d815a9646d1544826e973abeb74f5d1bca476a6
  ```

## Wire Into Diversinet.jl

- [x] Add `Diversinet_jll` as a dependency of `Diversinet.jl`.
- [x] Update `Diversinet/deps/build.jl` resolution order:

  1. explicit local dev override via `DIVERSINET_CPP_ROOT`
  2. explicit local library override via `DIVERSINET_CORE_LIB`
  3. default to `Diversinet_jll.libdiversinet`

- [x] Keep local source overrides for active C++ development.
- [x] Update the CxxWrap bridge build to include/link against the JLL-provided
      library by default.
- [ ] Verify from a clean `Diversinet.jl` environment on Linux:

  ```sh
  julia --project=. -e 'import Pkg; Pkg.build("Diversinet"); using Diversinet'
  ```

- [x] Revisit the macOS default path. The macOS core JLL is now built with
      clang/libc++, matching the local Julia CxxWrap bridge ABI.
- [x] Verify from a clean `Diversinet.jl` environment on macOS without
      `DIVERSINET_CPP_ROOT` or `DIVERSINET_CORE_LIB`.

## CI And Registration Readiness

- [ ] Add CI for the JLL recipe.
- [ ] Add CI in `Diversinet.jl` that installs from a clean environment and runs:

  ```julia
  using Diversinet
  ```

- [ ] Add focused `Pkg.test("Diversinet")` smoke tests.
- [ ] Ensure `Diversinet.jl` has no path-based dependencies for registered use.
- [ ] Ensure direct dependencies have `[compat]` entries.
- [ ] Register `Diversinet_jll` before registering `Diversinet.jl`.

## Useful Commands

Build the current local recipe:

```sh
BINARYBUILDER_AUTOMATIC_APPLE=true julia --project=. build_tarballs.jl --verbose
```

Current local development build of `Diversinet.jl`:

```sh
DIVERSINET_CPP_ROOT=~/repos/phyloploid_lib julia --project=. -e 'import Pkg; Pkg.build("Diversinet")'
```
