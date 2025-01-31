#!/usr/bin/env bash
set -eu

CUR_DIR="${PWD}"
cd "$(dirname "${BASH_SOURCE:-$0}")"

mkdir -p build/tools
cd build/tools

if [ ! -e "setup-llvm-mingw.bash" ]; then
  curl -sOL https://raw.githubusercontent.com/oov/ovbase/60418da401e611f977394bd36de68886415cd6a0/setup-llvm-mingw.bash
fi
. setup-llvm-mingw.bash --dir $PWD

cd ..

REBUILD=1
SKIP_TESTS=0
CREATE_ZIP=0
CMAKE_BUILD_TYPE=Release

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--debug)
      CMAKE_BUILD_TYPE=Debug
      shift
      ;;
    -q|--quick)
      REBUILD=0
      shift
      ;;
    -s|--skip-tests)
      SKIP_TESTS=1
      shift
      ;;
    -z|--zip)
      CREATE_ZIP=1
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      shift
      ;;
  esac
done

for arch in i686; do
  destdir="${PWD}/${CMAKE_BUILD_TYPE}/${arch}"
  if [ "${REBUILD}" -eq 1 ]; then
    rm -rf "${destdir}"
    cmake -S .. -B "${destdir}" --preset default \
      -DFORMAT_SOURCES=ON \
      -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
      -DCMAKE_TOOLCHAIN_FILE="src/cmake/llvm-mingw.cmake" \
      -DCMAKE_C_COMPILER="${arch}-w64-mingw32-clang"
  fi
  cmake --build "${destdir}"
  if [ "${SKIP_TESTS}" -eq 0 ]; then
    ctest --test-dir "${destdir}/src" --output-on-failure --output-junit testlog.xml
  fi
done

destdir="${PWD}/${CMAKE_BUILD_TYPE}"
if [ "${REBUILD}" -eq 1 ]; then
  rm -rf "${destdir}/bin"
fi
mkdir -p "${destdir}/bin"
cp -r "${destdir}/i686/bin/"* "${destdir}/bin"

if [ "${CREATE_ZIP}" -eq 1 ]; then
  rm -rf "${destdir}/dist"
  mkdir -p "${destdir}/dist"
  cd "${destdir}/bin"
  cmake -E tar cf "${destdir}/dist/${CMAKE_BUILD_TYPE}.zip" --format=zip .
  cd ../..
fi

cd "${CUR_DIR}"
