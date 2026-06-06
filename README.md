# Diversinet_jll Local Build Notes

This workspace is for developing a BinaryBuilder recipe for the native
`libdiversinet` library.

The current recipe builds a core-only JLL:

```text
Diversinet_jll provides libdiversinet
Diversinet.jl builds/loads its CxxWrap bridge separately
```

## 1. Refresh The Local Source Archive

Run this after changing `~/repos/phyloploid_lib`:

```sh
cd ~/repos/Diversinet_jll

env COPYFILE_DISABLE=1 LC_ALL=C tar \
  --exclude=.git \
  --exclude=build \
  --exclude=builddir \
  --exclude=build-meson \
  --exclude=.DS_Store \
  --exclude='._*' \
  --exclude=ide \
  --exclude=.vscode \
  --exclude=lib \
  -czf sources/phyloploid_lib-local.tar.gz \
  -C ~/repos phyloploid_lib
```

Then compute the new archive hash:

```sh
shasum -a 256 sources/phyloploid_lib-local.tar.gz
```

Copy that SHA256 into the `ArchiveSource` entry in `build_tarballs.jl`.

## 2. Build Product Tarballs

Build all platforms listed in `build_tarballs.jl`:

```sh
cd ~/repos/Diversinet_jll

BINARYBUILDER_AUTOMATIC_APPLE=true julia --project=. build_tarballs.jl --verbose
```

The generated binary tarballs are written to `products/`.

Current target platforms:

```text
aarch64-apple-darwin
aarch64-linux-gnu-libgfortran5-cxx11
x86_64-linux-gnu-libgfortran5-cxx11
```

The Linux targets are explicitly set to `libgfortran5`/`cxx11` so BinaryBuilder
uses a C++20-capable GCC toolchain.

The macOS target is built manually with BinaryBuilder's clang toolchain so the
core library uses Apple's libc++ ABI. That keeps it compatible with the local
CxxWrap bridge built by `Diversinet.jl`.

## 3. Regenerate The JLL Wrapper Package

After the product tarballs exist, generate the local wrapper package without
uploading anything:

```sh
cd ~/repos/Diversinet_jll

BINARYBUILDER_AUTOMATIC_APPLE=true julia --project=. build_tarballs.jl \
  --deploy-jll=local \
  --skip-build
```

This writes the generated package to:

```text
~/.julia/dev/Diversinet_jll
```

## 4. Smoke Test The Generated JLL

Develop the generated JLL into a temporary Julia environment and verify it
exposes and loads `libdiversinet`:

```sh
cd ~/repos/Diversinet_jll

julia --startup-file=no --temp --project -e '
  import Pkg
  Pkg.develop(path=joinpath(homedir(), ".julia/dev/Diversinet_jll"))
  Pkg.instantiate()
  using Libdl, Diversinet_jll
  println(Diversinet_jll.libdiversinet)
  h = Libdl.dlopen(Diversinet_jll.libdiversinet)
  println(h != C_NULL)
  Libdl.dlclose(h)
'
```

Expected final output includes:

```text
true
```

On macOS, verify that the artifact uses libc++ and exports the `std::__1` ABI:

```sh
otool -L ~/.julia/artifacts/8d815a9646d1544826e973abeb74f5d1bca476a6/lib/libdiversinet.dylib
nm -gU ~/.julia/artifacts/8d815a9646d1544826e973abeb74f5d1bca476a6/lib/libdiversinet.dylib | rg 'readNewick|__cxx11|__1'
```

## Known Warnings

BinaryBuilder currently packages successfully, but reports:

```text
Unable to find valid license file in "${prefix}/share/licenses/Diversinet"
```

Linux also reports:

```text
Linked library libgcc_s.so.1 could not be resolved and could not be auto-mapped
```

The Linux warning should be resolved or understood before treating the JLL as
release-ready.
