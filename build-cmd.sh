#!/usr/bin/env bash

cd "$(dirname "$0")"

echo "Building tracy library"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e
# complain about unset env variables
set -u

# Check autobuild is around or fail
if [ -z "$AUTOBUILD" ] ; then
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

top="$(pwd)"
stage_dir="$(pwd)/stage"
mkdir -p "$stage_dir"
tmp_dir="$(pwd)/tmp"
mkdir -p "$tmp_dir"

# Load autobuild provided shell functions and variables
srcenv_file="$tmp_dir/ab_srcenv.sh"
"$autobuild" source_environment > "$srcenv_file"
. "$srcenv_file"

build_id=${AUTOBUILD_BUILD_ID:=0}
tracy_version="$(sed -n -E 's/(v[0-9]+\.[0-9]+\.[0-9]+) \(.+\)/\1/p' tracy/NEWS | head -1)"
echo "${tracy_version}.${build_id}" > "${stage_dir}/VERSION.txt"

source_dir="tracy"

mkdir -p "build"
pushd "build"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            load_vsvars
            mkdir -p "$stage_dir/bin"
            mkdir -p "capture"
            pushd "capture"
                cmake $(cygpath -m "$top/$source_dir/capture") -G Ninja -DCMAKE_BUILD_TYPE=Release
                cmake --build . --config Release

                cp -a tracy-capture.exe $stage_dir/bin
            popd

            mkdir -p "csvexport"
            pushd "csvexport"
                cmake $(cygpath -m "$top/$source_dir/csvexport") -G Ninja -DCMAKE_BUILD_TYPE=Release
                cmake --build . --config Release

                cp -a tracy-csvexport.exe $stage_dir/bin
            popd

            mkdir -p "profiler"
            pushd "profiler"
                cmake $(cygpath -m "$top/$source_dir/profiler") -G Ninja -DCMAKE_BUILD_TYPE=Release
                cmake --build . --config Release

                cp -a tracy-profiler.exe $stage_dir/bin
            popd

            mkdir -p "update"
            pushd "update"
                cmake $(cygpath -m "$top/$source_dir/update") -G Ninja -DCMAKE_BUILD_TYPE=Release
                cmake --build . --config Release

                cp -a tracy-update.exe $stage_dir/bin
            popd
# See common code below that copies haders to packages/include/
        ;;

        darwin*)
            export MACOSX_DEPLOYMENT_TARGET="$LL_BUILD_DARWIN_DEPLOY_TARGET"
            export MACOSX_ARCHITECTURES="arm64;x86_64"
            export MACOSX_EXTRA_CMAKE_ARGS="-DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET='${MACOSX_DEPLOYMENT_TARGET}' -DCMAKE_OSX_ARCHITECTURES='${MACOSX_ARCHITECTURES}' -DCMAKE_IGNORE_PREFIX_PATH='/usr/local/'"

            # force CPM dependencies glfw and freetype to be built statically to make built executables easier to deploy anywhere
            patch --directory "$top/$source_dir" -p1 < "$top/tracy-deps-static.patch"

            mkdir -p "$stage_dir/bin"
            mkdir -p "capture"
            pushd "capture"
                cmake "$top/$source_dir/capture" -G Ninja ${MACOSX_EXTRA_CMAKE_ARGS} \
                    -DDOWNLOAD_CAPSTONE=ON -DDOWNLOAD_GLFW=ON -DDOWNLOAD_FREETYPE=ON

                cmake --build . --config Release

                cp -a tracy-capture $stage_dir/bin
            popd

            mkdir -p "csvexport"
            pushd "csvexport"
                cmake "$top/$source_dir/csvexport" -G Ninja ${MACOSX_EXTRA_CMAKE_ARGS} \
                    -DDOWNLOAD_CAPSTONE=ON -DDOWNLOAD_GLFW=ON -DDOWNLOAD_FREETYPE=ON
                cmake --build . --config Release

                cp -a tracy-csvexport $stage_dir/bin
            popd

            mkdir -p "profiler"
            pushd "profiler"
                cmake "$top/$source_dir/profiler" -G Ninja ${MACOSX_EXTRA_CMAKE_ARGS} \
                    -DDOWNLOAD_CAPSTONE=ON -DDOWNLOAD_GLFW=ON -DDOWNLOAD_FREETYPE=ON
                cmake --build . --config Release

                cp -a tracy-profiler $stage_dir/bin
            popd

            mkdir -p "update"
            pushd "update"
                cmake "$top/$source_dir/update" -G Ninja ${MACOSX_EXTRA_CMAKE_ARGS} \
                    -DDOWNLOAD_CAPSTONE=ON -DDOWNLOAD_GLFW=ON -DDOWNLOAD_FREETYPE=ON
                cmake --build . --config Release

                cp -a tracy-update $stage_dir/bin
            popd
# See common code below that copies haders to packages/include/
        ;;

        linux*)
            # force CPM dependencies glfw and freetype to be built statically to make built executables easier to deploy anywhere
            patch --directory "$top/$source_dir" -p1 < "$top/tracy-deps-static.patch"

            mkdir -p "$stage_dir/bin"
            mkdir -p "capture"
            pushd "capture"
                cmake "$top/$source_dir/capture" -G Ninja -DCMAKE_BUILD_TYPE=Release \
                    -DDOWNLOAD_CAPSTONE=ON -DDOWNLOAD_GLFW=ON -DDOWNLOAD_FREETYPE=ON
                cmake --build . --config Release

                cp -a tracy-capture $stage_dir/bin
            popd

            mkdir -p "csvexport"
            pushd "csvexport"
                cmake "$top/$source_dir/csvexport" -G Ninja -DCMAKE_BUILD_TYPE=Release \
                    -DDOWNLOAD_CAPSTONE=ON -DDOWNLOAD_GLFW=ON -DDOWNLOAD_FREETYPE=ON
                cmake --build . --config Release

                cp -a tracy-csvexport $stage_dir/bin
            popd

            mkdir -p "profiler"
            pushd "profiler"
                cmake "$top/$source_dir/profiler" -G Ninja -DCMAKE_BUILD_TYPE=Release -DLEGACY=ON \
                    -DDOWNLOAD_CAPSTONE=ON -DDOWNLOAD_GLFW=ON -DDOWNLOAD_FREETYPE=ON
                cmake --build . --config Release

                cp -a tracy-profiler $stage_dir/bin
            popd

            mkdir -p "update"
            pushd "update"
                cmake "$top/$source_dir/update" -G Ninja -DCMAKE_BUILD_TYPE=Release \
                    -DDOWNLOAD_CAPSTONE=ON -DDOWNLOAD_GLFW=ON -DDOWNLOAD_FREETYPE=ON
                cmake --build . --config Release

                cp -a tracy-update $stage_dir/bin
            popd
# See common code below that copies haders to packages/include/
        ;;
    esac
popd

# Common code that copies headers to packages/include/
pushd "$source_dir"
	mkdir -p "$stage_dir/include/tracy"
	cp -a public/* "$stage_dir/include/tracy/"
popd

# copy license file
mkdir -p "$stage_dir/LICENSES"
cp tracy/LICENSE "$stage_dir/LICENSES/tracy_license.txt"
