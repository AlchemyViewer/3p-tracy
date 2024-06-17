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

tracy_version="$(sed -n -E 's/(v[0-9]+\.[0-9]+\.[0-9]+) \(.+\)/\1/p' tracy/NEWS | head -1)"
echo "${tracy_version}" > "${stage_dir}/VERSION.txt"

source_dir="tracy"
pushd "$source_dir"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            load_vsvars

            # First build the client lib
            mkdir -p "$stage_dir/tools/tracy"
            mkdir -p "$stage_dir/include/tracy"
            mkdir -p "$stage_dir/lib/debug"
            mkdir -p "$stage_dir/lib/release"

            mkdir -p "build_debug"
            pushd "build_debug"
                cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Debug .. \
                        -DCMAKE_INSTALL_PREFIX="$(cygpath -m $stage_dir)/debug" \
                        -DTRACY_ON_DEMAND=ON -DTRACY_ONLY_LOCALHOST=ON -DTRACY_NO_BROADCAST=ON

                cmake --build . --config Debug --clean-first
                cmake --install . --config Debug
            popd

            mkdir -p "build_release"
            pushd "build_release"
                cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release .. \
                        -DCMAKE_INSTALL_PREFIX="$(cygpath -m $stage_dir)/release" \
                        -DTRACY_ON_DEMAND=ON -DTRACY_ONLY_LOCALHOST=ON -DTRACY_NO_BROADCAST=ON

                cmake --build . --config Release --clean-first
                cmake --install . --config Release
            popd

            cp -a $stage_dir/debug/lib/*.lib $stage_dir/lib/debug/
            cp -a $stage_dir/release/lib/*.lib $stage_dir/lib/release/

            cp -a $stage_dir/release/include/* $stage_dir/include/tracy

            cmd.exe /c $(cygpath -w "vcpkg/install_vcpkg_dependencies.bat")

            msbuild.exe $(cygpath -w "capture/build/win32/capture.sln") /p:Configuration=Release /p:Platform=$AUTOBUILD_WIN_VSPLATFORM
            msbuild.exe $(cygpath -w "csvexport/build/win32/csvexport.sln") /p:Configuration=Release /p:Platform=$AUTOBUILD_WIN_VSPLATFORM
            msbuild.exe $(cygpath -w "import-chrome/build/win32/import-chrome.sln") /p:Configuration=Release /p:Platform=$AUTOBUILD_WIN_VSPLATFORM
            msbuild.exe $(cygpath -w "profiler/build/win32/Tracy.sln") /p:Configuration=Release /p:Platform=$AUTOBUILD_WIN_VSPLATFORM
            msbuild.exe $(cygpath -w "update/build/win32/update.sln") /p:Configuration=Release /p:Platform=$AUTOBUILD_WIN_VSPLATFORM

            cp -a capture/build/win32/x64/Release/capture.exe $stage_dir/tools/tracy/
            cp -a csvexport/build/win32/x64/Release/csvexport.exe $stage_dir/tools/tracy/
            cp -a import-chrome/build/win32/x64/Release/import-chrome.exe $stage_dir/tools/tracy/
            cp -a profiler/build/win32/x64/Release/Tracy.exe $stage_dir/tools/tracy/
            cp -a update/build/win32/x64/Release/update.exe $stage_dir/tools/tracy/
        ;;

        darwin*)
            mkdir -p "build"
            pushd "build"
                cmake .. -G "Ninja Multi-Config" -DCMAKE_BUILD_TYPE=Release .. \
                        -DCMAKE_INSTALL_PREFIX="${stage_dir}" \
                        -DTRACY_ON_DEMAND=ON -DTRACY_ONLY_LOCALHOST=ON -DTRACY_NO_BROADCAST=ON

                cmake --build . --config Release
                cmake --install . --config Release
            popd

            mkdir -p "$stage_dir/lib/release"
            mv "$stage_dir/lib/libtracy.a" "$stage_dir/lib/release/libtracy.a"

            mkdir -p "$stage_dir/include/tracy"
            cp Tracy.hpp "$stage_dir/include/tracy/"
			cp TracyOpenGL.hpp "$stage_dir/include/tracy/"

            rm -r "$stage_dir/lib/cmake"
        ;;
    esac
popd

# copy license file
mkdir -p "$stage_dir/LICENSES"
cp tracy/LICENSE "$stage_dir/LICENSES/tracy_license.txt"
