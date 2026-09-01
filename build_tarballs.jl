using BinaryBuilder
using Pkg

name = "Diversinet"
version = v"0.1.0"

sources = [
    GitSource(
        "https://github.com/mikeryanmay/Diversinet.git",
        "0727a35cc367b123d7c32fe90f27e885687a8c4e",
    ),
    GitSource(
        "https://github.com/mikeryanmay/Diversinet.jl.git",
        "3c08479d4ed8286eafefc4861266d440091df9a3",
    ),
]

script = raw"""
cd ${WORKSPACE}/srcdir/Diversinet

# Meson's macOS cross files select GCC/libstdc++, which is ABI-incompatible
# with Julia. Build the core explicitly with clang/libc++ on Apple platforms.
if [[ "${target}" == *apple* ]]; then
    mkdir -p build/core-objects "${libdir}" "${includedir}" "${libdir}/pkgconfig"

    core_sources=(
        src/Data/Reader/Newick/NewickParser.cpp
        src/Data/Reader/Newick/TreeNode.cpp
        src/Data/Structure/Edge.cpp
        src/Data/Structure/Network.cpp
        src/Data/Structure/Node.cpp
        src/Interface/DiversinetInterface.cpp
        src/Likelihood/Approximator/BaseApproximator.cpp
        src/Likelihood/Approximator/DefaultApproximator.cpp
        src/Likelihood/Approximator/Factory.cpp
        src/Likelihood/ConditionTypes/ConditionType.cpp
        src/Likelihood/Kernels/CPU/EigenIntegrationKernel.cpp
        src/Likelihood/Kernels/CPU/EigenKernels.cpp
        src/Likelihood/Scheduler/BaseScheduler.cpp
        src/Likelihood/Scheduler/Event.cpp
        src/Likelihood/StateTypes/Utils.cpp
        src/Likelihood/StateTypes/Vector/EigenState.cpp
        src/Models/BaseModel.cpp
        src/Models/Factory.cpp
        src/Models/SimpleNetworkModel.cpp
        src/Parameters/Container.cpp
        src/Simulate/BaseSimulator.cpp
        src/Utils/MemoryPool/EigenCPU.cpp
        src/Utils/Output/OutputManager.cpp
        src/Utils/Parallel/Manager.cpp
    )

    core_objects=()
    for src in "${core_sources[@]}"; do
        obj="build/core-objects/${src//\//_}.o"
        core_objects+=("${obj}")
        "${target}-clang++" \
            -std=c++20 -O3 -fPIC \
            -Iinclude -Isrc -I"${includedir}" -I"${includedir}/eigen3" \
            -c "${src}" -o "${obj}"
    done

    "${target}-clang++" \
        -dynamiclib \
        -install_name "@rpath/libdiversinet.dylib" \
        -o "${libdir}/libdiversinet.dylib" \
        "${core_objects[@]}" \
        -L"${libdir}" -lboost_random

    install -Dvm 644 include/Diversinet/DiversinetInterface.h \
        "${includedir}/Diversinet/DiversinetInterface.h"
    install -Dvm 644 LICENSE "${prefix}/share/licenses/Diversinet/LICENSE"

    cat > "${libdir}/pkgconfig/diversinet.pc" <<EOF
prefix=${prefix}
libdir=${libdir}
includedir=${includedir}

Name: libdiversinet
Description: Likelihood calculation and simulation for phylogenetic networks
Version: 0.1.0
Libs: -L\${libdir} -ldiversinet
Cflags: -I\${includedir}
EOF
else
    meson setup build/core \
        --cross-file="${MESON_TARGET_TOOLCHAIN%.*}_gcc.meson" \
        --prefix="${prefix}" \
        --libdir=lib \
        --buildtype=release \
        -Dprograms=false \
        -Dtests=false
    meson compile -C build/core
    meson install -C build/core
fi

# Build the CxxWrap bridge only after libdiversinet has been installed into the
# artifact prefix. libcxxwrap_julia_jll and libjulia_jll populate this prefix.
cd ${WORKSPACE}/srcdir/Diversinet.jl/cpp

if [[ "${target}" == *apple* ]]; then
    mkdir -p build
    "${target}-clang++" \
        -std=c++20 -O3 -fPIC \
        -I"${includedir}" -I"${includedir}/julia" \
        -c jlDiversinetInterface.cpp \
        -o build/jlDiversinetInterface.o
    "${target}-clang++" \
        -dynamiclib \
        -install_name "@rpath/libjlDiversinetInterface.dylib" \
        -Wl,-rpath,@loader_path \
        -o "${libdir}/libjlDiversinetInterface.dylib" \
        build/jlDiversinetInterface.o \
        -L"${libdir}" -ldiversinet -lcxxwrap_julia
else
    meson setup build \
        --cross-file="${MESON_TARGET_TOOLCHAIN%.*}_gcc.meson" \
        --prefix="${prefix}" \
        --libdir=lib \
        --buildtype=release \
        -Dcore_root="${prefix}" \
        -Dcore_lib="${libdir}/libdiversinet.${dlext}" \
        -Dcore_include_dirs="${includedir}" \
        -Dcxxwrap_prefix="${prefix}" \
        -Djulia_include_dir="${includedir}"
    meson compile -C build
    meson install -C build
fi
"""

base_platforms = [
    Platform("aarch64", "macos"),
    Platform("x86_64", "macos"),
    Platform("x86_64", "linux"; libc = "glibc", cxxstring_abi = "cxx11", libgfortran_version = v"5.0.0"),
    Platform("aarch64", "linux"; libc = "glibc", cxxstring_abi = "cxx11", libgfortran_version = v"5.0.0"),
]

# The initial release supports Julia 1.12 only, keeping the CxxWrap ABI matrix
# small. Additional Julia minor versions can be added here later.
julia_versions = [v"1.12.0"]
platforms = Platform[]
for base_platform in base_platforms, julia_version in julia_versions
    platform = deepcopy(base_platform)
    platform["julia_version"] = string(julia_version)
    push!(platforms, platform)
end

products = [
    LibraryProduct("libdiversinet", :libdiversinet),
    LibraryProduct("libjlDiversinetInterface", :libjlDiversinetInterface),
]

dependencies = [
    Dependency("boost_jll"),
    Dependency("Eigen_jll"),
    Dependency("libcxxwrap_julia_jll"; compat = "0.14.10"),
    # Julia 1.12 is selected by each platform tag. libjulia_jll 1.11 supplies
    # build-only C headers; newer libjulia_jll releases are not registered.
    BuildDependency(PackageSpec(; name = "libjulia_jll", version = "1.11.0")),
    HostBuildDependency("Ninja_jll"),
]

build_tarballs(
    ARGS,
    name,
    version,
    sources,
    script,
    platforms,
    products,
    dependencies;
    julia_compat = "1.12",
    preferred_gcc_version = v"10",
)
