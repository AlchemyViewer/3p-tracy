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
pushd "$source_dir"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            load_vsvars

            cmake . -G "$AUTOBUILD_WIN_CMAKE_GEN" -DCMAKE_C_FLAGS="$LL_BUILD_RELEASE"
            build_sln "tracy.sln" "Release|$AUTOBUILD_WIN_VSPLATFORM" "tracy"

            mkdir -p "$stage_dir/lib/release"
            mv Release/tracy.lib "$stage_dir/lib/release"

# See common code below that copies haders to packages/include/
        ;;

        darwin*)
            cmake . -DCMAKE_INSTALL_PREFIX:STRING="${stage_dir}"

# See common code below that copies haders to packages/include/
        ;;
    esac

# Common code that copies headers to packages/include/
# Tracy is "mostly" a header-only project -- it has a few .cpp files
#    TracyClient.cpp
#    client/*.cpp
#    common/*.cpp
#    libbacktrace/*.cpp
# that needs to be included if not building/linking to a library.
# The other .c/.cpp files are for building the Tracy server which aren't needed here.
	mkdir -p "$stage_dir/include/tracy"
	cp *.cpp "$stage_dir/include/tracy/"
	cp *.hpp "$stage_dir/include/tracy/"
	cp *.h   "$stage_dir/include/tracy/"

	mkdir -p        "$stage_dir/include/tracy/common"
	cp common/*.cpp "$stage_dir/include/tracy/common"
	cp common/*.hpp "$stage_dir/include/tracy/common"
	cp common/*.h   "$stage_dir/include/tracy/common"

	mkdir -p        "$stage_dir/include/tracy/client"
	cp common/*.cpp "$stage_dir/include/tracy/client"
	cp client/*.hpp "$stage_dir/include/tracy/client"
	cp client/*.h   "$stage_dir/include/tracy/client"

	mkdir -p        "$stage_dir/include/tracy/libbacktrace"
	cp common/*.cpp "$stage_dir/include/tracy/client"
	cp client/*.hpp "$stage_dir/include/tracy/client"
	cp client/*.h   "$stage_dir/include/tracy/client"
popd

# copy license file
mkdir -p "$stage_dir/LICENSES"
cp tracy/LICENSE "$stage_dir/LICENSES/tracy_license.txt"
