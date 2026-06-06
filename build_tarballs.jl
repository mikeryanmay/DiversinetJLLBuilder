using BinaryBuilder
using Pkg

name = "Diversinet"
version = v"0.0.1"

sources = [
    ArchiveSource(
        "file:///Users/mike/repos/Diversinet_jll/sources/phyloploid_lib-local.tar.gz",
        "d7087eed613b1b18615bbd4f06d9a0dec4ed9b938a68906a2581ed19edb842e7",
    ),
]

script = raw"""
cd ${WORKSPACE}/srcdir/phyloploid_lib

if [[ "${target}" == *apple* ]]; then
    mkdir -p build/manual-objects "${libdir}" "${includedir}" "${libdir}/pkgconfig"

    sources=(
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

    objects=()
    for src in "${sources[@]}"; do
        obj="build/manual-objects/${src//\//_}.o"
        objects+=("${obj}")
        "${target}-clang++" \
            -std=c++20 \
            -O3 \
            -fPIC \
            -Iapi \
            -Isrc \
            -I"${includedir}" \
            -I"${includedir}/eigen3" \
            -c "${src}" \
            -o "${obj}"
    done

    "${target}-clang++" \
        -dynamiclib \
        -install_name "@rpath/libdiversinet.dylib" \
        -o "${libdir}/libdiversinet.dylib" \
        "${objects[@]}" \
        -L"${libdir}" \
        -lboost_random

    install -m 644 api/DiversinetInterface.h "${includedir}/DiversinetInterface.h"

    cat > "${libdir}/pkgconfig/diversinet.pc" <<EOF
prefix=${prefix}
libdir=${libdir}
includedir=${includedir}

Name: libdiversinet
Description: Diversinet native library
Version: 0.0.1
Libs: -L\${libdir} -ldiversinet
Cflags: -I\${includedir}
EOF
else
    meson setup build \
        --cross-file="${MESON_TARGET_TOOLCHAIN%.*}_gcc.meson" \
        --prefix="${prefix}" \
        --libdir=lib \
        --buildtype=release \
        -Dprograms=false \
        -Dtests=false

    meson compile -C build
    meson install -C build
fi
"""

platforms = [
    Platform("aarch64", "macos"),
    Platform("x86_64", "linux"; libc = "glibc", cxxstring_abi = "cxx11", libgfortran_version = v"5.0.0"),
    Platform("aarch64", "linux"; libc = "glibc", cxxstring_abi = "cxx11", libgfortran_version = v"5.0.0"),
]

products = [
    LibraryProduct("libdiversinet", :libdiversinet),
]

dependencies = [
    Dependency("boost_jll"),
    Dependency("Eigen_jll"),
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
    julia_compat = "1.6",
)
