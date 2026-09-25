#!/usr/bin/env bash
# Linux -> Windows x64 cross-build. No precompiled FFmpeg is downloaded.
# Ubuntu 24.04 packages (no Wine is required in this job):
# gcc-mingw-w64-x86-64-win32 g++-mingw-w64-x86-64-win32
# binutils-mingw-w64-x86-64 mingw-w64-x86-64-dev nasm cmake ninja-build
# make pkg-config curl xz-utils jq patch
set -euo pipefail

recipe_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$recipe_dir/.." && pwd)"
lock="$recipe_dir/dependencies.lock.json"
out="${1:-$repo_dir/ci-out}"
if [[ -e "$out" ]]; then
    echo "Output already exists; choose a new output directory: $out" >&2
    exit 1
fi
mkdir -p -- "$out/bin" "$out/docs" "$out/sources"
out="$(cd -- "$out" && pwd)"
build_root="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/lz-ffmpeg.XXXXXXXX")"
prefix="$build_root/prefix"
bundle="$build_root/FFmpeg-corresponding-source"
mkdir -p "$prefix" "$bundle/archives" "$bundle/recipe/patches" "$bundle/recipe/licenses" "$bundle/licenses" "$bundle/build-information"
cp "$lock" "$bundle/recipe/dependencies.lock.json"
cp "${BASH_SOURCE[0]}" "$bundle/recipe/Build-FFmpeg.sh"
cp "$recipe_dir/patches/x265-4.1-version.patch" "$bundle/recipe/patches/"
cp "$recipe_dir/licenses/GCC-COPYING.RUNTIME" "$bundle/recipe/licenses/"
jobs="${BUILD_JOBS:-$(nproc)}"
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { echo "BUILD_JOBS must be a positive integer" >&2; exit 1; }
export CC=x86_64-w64-mingw32-gcc-win32
export CXX=x86_64-w64-mingw32-g++-win32
export AR=x86_64-w64-mingw32-ar
export RANLIB=x86_64-w64-mingw32-ranlib
export STRIP=x86_64-w64-mingw32-strip
export PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig"
export PKG_CONFIG_PATH="$prefix/lib/pkgconfig"
export SOURCE_DATE_EPOCH=1789948800
export LC_ALL=C
for command in "$CC" "$CXX" "$AR" "$RANLIB" "$STRIP" nasm cmake ninja make pkg-config curl tar xz jq patch; do
    command -v "$command" >/dev/null || { echo "Missing build tool: $command" >&2; exit 1; }
done

for component in ffmpeg x264 x265; do
    url="$(jq -er --arg component "$component" '.[$component].url' "$lock")"
    filename="$(jq -er --arg component "$component" '.[$component].file' "$lock")"
    digest="$(jq -er --arg component "$component" '.[$component].sha256' "$lock")"
    archive="$bundle/archives/$filename"
    # The companion source archive can rebuild without re-fetching these inputs.
    if [[ -f "$recipe_dir/../archives/$filename" ]]; then
        cp "$recipe_dir/../archives/$filename" "$archive"
    else
        curl --fail --location --retry 3 --connect-timeout 20 --max-time 240 "$url" -o "$archive"
    fi
    printf '%s  %s\n' "$digest" "$archive" | sha256sum --check --strict
    mkdir -p "$build_root/$component"
    tar -xzf "$archive" --strip-components=1 -C "$build_root/$component"
done

# Archive version metadata only: no codec implementation patches.
patch --batch --fuzz=0 -d "$build_root/x265" -p1 < "$recipe_dir/patches/x265-4.1-version.patch"
# Prevent a parent checkout's Git revision from being mistaken for FFmpeg's.
cp "$build_root/ffmpeg/RELEASE" "$build_root/ffmpeg/VERSION"
cp "$build_root/ffmpeg/VERSION" "$bundle/build-information/ffmpeg-VERSION"
cp "$build_root/x265/x265Version.txt" "$bundle/build-information/x265Version.txt"

{
    printf 'Target: Windows x86_64, MinGW-w64 win32 threads, static external codecs\n'
    printf 'Source date epoch: %s\n' "$SOURCE_DATE_EPOCH"
    "$CC" --version
    "$CXX" --version
    nasm -v
    cmake --version
    ninja --version
    if command -v dpkg-query >/dev/null; then
        dpkg-query -W gcc-mingw-w64-x86-64-win32 g++-mingw-w64-x86-64-win32 gcc-mingw-w64-x86-64-win32-runtime gcc-mingw-w64-base binutils-mingw-w64-x86-64 mingw-w64-common mingw-w64-x86-64-dev nasm cmake ninja-build make pkg-config curl xz-utils jq patch
    fi
} > "$bundle/build-information/toolchain.txt"

(
    cd "$build_root/x264"
    ./configure --host=x86_64-w64-mingw32 --cross-prefix=x86_64-w64-mingw32- \
        --prefix="$prefix" --enable-static --disable-cli --disable-opencl \
        --disable-lavf --disable-swscale --extra-cflags='-O2' \
        --extra-ldflags='-static' 2>&1 | tee "$bundle/build-information/x264-configure.txt"
    make -j"$jobs"
    make install
    cp config.log "$bundle/build-information/x264-config.log"
)

cmake -S "$build_root/x265/source" -B "$build_root/x265-build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
    -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres \
    -DCMAKE_AR="$AR" -DCMAKE_RANLIB="$RANLIB" \
    -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DENABLE_TESTS=OFF \
    -DENABLE_HDR10_PLUS=OFF -DENABLE_LIBNUMA=OFF -DENABLE_LIBVMAF=OFF \
    -DENABLE_SVT_HEVC=OFF -DENABLE_PPA=OFF -DENABLE_VTUNE=OFF \
    -DENABLE_ALPHA=OFF -DENABLE_MULTIVIEW=OFF -DENABLE_SCC_EXT=OFF \
    -DHIGH_BIT_DEPTH=OFF -DENABLE_ASSEMBLY=ON -DSTATIC_LINK_CRT=ON \
    -DCMAKE_EXE_LINKER_FLAGS='-static -static-libgcc -static-libstdc++' \
    -DCMAKE_ASM_NASM_FLAGS=-w-macro-params-legacy \
    2>&1 | tee "$bundle/build-information/x265-configure.txt"
cmake --build "$build_root/x265-build" --parallel "$jobs"
cmake --install "$build_root/x265-build"
cp "$build_root/x265-build/CMakeCache.txt" "$bundle/build-information/x265-CMakeCache.txt"
# Ensure the C linker used by FFmpeg receives the C++ standard library.
sed -i 's/^Libs.private:.*/Libs.private: -lstdc++ -lm/' "$prefix/lib/pkgconfig/x265.pc"

(
    cd "$build_root/ffmpeg"
    ./configure --prefix="$prefix" --target-os=mingw32 --arch=x86_64 \
        --enable-cross-compile --cross-prefix=x86_64-w64-mingw32- \
        --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --strip="$STRIP" \
        --pkg-config=pkg-config --pkg-config-flags=--static \
        --enable-gpl --enable-static --disable-shared \
        --enable-libx264 --enable-libx265 --enable-w32threads --disable-pthreads \
        --disable-autodetect --disable-network --disable-ffplay --disable-doc --disable-debug \
        --extra-cflags="-I$prefix/include -O2" --extra-ldflags="-L$prefix/lib -static -static-libgcc -static-libstdc++" \
        --extra-libs=-lstdc++ --extra-version=lz-offline \
        2>&1 | tee "$bundle/build-information/ffmpeg-configure.txt"
    make -j"$jobs" ffmpeg.exe ffprobe.exe
    cp ffmpeg.exe ffprobe.exe "$out/bin/"
    cp ffbuild/config.log "$bundle/build-information/ffmpeg-config.log"
    cp ffbuild/config.mak "$bundle/build-information/ffmpeg-config.mak"
    cp config.h "$bundle/build-information/ffmpeg-config.h"
)

# Fail closed if a non-system DLL slipped into this static build.
for executable in "$out/bin/ffmpeg.exe" "$out/bin/ffprobe.exe"; do
    x86_64-w64-mingw32-objdump -p "$executable" > "$bundle/build-information/$(basename "$executable").pe.txt"
    while IFS= read -r dll; do
        case "${dll,,}" in
            kernel32.dll|msvcrt.dll|advapi32.dll|bcrypt.dll|crypt32.dll|gdi32.dll|ole32.dll|oleaut32.dll|psapi.dll|secur32.dll|shell32.dll|shlwapi.dll|user32.dll|userenv.dll|version.dll|winmm.dll|ws2_32.dll|ntdll.dll|setupapi.dll|d3d11.dll|dxgi.dll|mfplat.dll|mfuuid.dll|strmiids.dll|avicap32.dll|vfw32.dll) ;;
            *) echo "Unexpected DLL dependency: $dll in $executable" >&2; exit 1 ;;
        esac
    done < <(awk '/DLL Name:/ {print $3}' "$bundle/build-information/$(basename "$executable").pe.txt")
done

cp "$build_root/ffmpeg/COPYING.GPLv2" "$bundle/licenses/FFmpeg-COPYING.GPLv2"
cp "$build_root/ffmpeg/COPYING.GPLv3" "$bundle/licenses/FFmpeg-COPYING.GPLv3"
cp "$build_root/ffmpeg/COPYING.LGPLv2.1" "$bundle/licenses/FFmpeg-COPYING.LGPLv2.1"
cp "$build_root/ffmpeg/COPYING.LGPLv3" "$bundle/licenses/FFmpeg-COPYING.LGPLv3"
cp "$build_root/ffmpeg/LICENSE.md" "$bundle/licenses/FFmpeg-LICENSE.md"
cp "$build_root/x264/COPYING" "$bundle/licenses/x264-COPYING"
cp "$build_root/x265/COPYING" "$bundle/licenses/x265-COPYING"
# Preserve the notices for statically linked compiler/MinGW runtime code too.
# Debian/Ubuntu packages install consolidated upstream copyright/license files.
for package in gcc-mingw-w64-base gcc-mingw-w64-x86-64-win32-runtime mingw-w64-common mingw-w64-x86-64-dev; do
    copyright="/usr/share/doc/$package/copyright"
    if [[ ! -f "$copyright" ]]; then
        echo "Missing toolchain copyright/license file: $copyright" >&2
        exit 1
    fi
    cp -L "$copyright" "$bundle/licenses/$package-copyright"
done
for license in GPL-2 GPL-3 LGPL-2.1 LGPL-3; do
    cp -L "/usr/share/common-licenses/$license" "$bundle/licenses/toolchain-$license"
done
cp "$recipe_dir/licenses/GCC-COPYING.RUNTIME" "$bundle/licenses/GCC-COPYING.RUNTIME"

{
    printf 'FFmpeg / x264 / x265 - materiais de terceiros\n\n'
    printf 'Compilacao propria para Windows x64 a partir das fontes identificadas abaixo.\n'
    printf 'FFmpeg 8.1.3, com libx264 e libx265 estaticos e AAC nativo.\n'
    printf 'Nenhum binario FFmpeg de 2018 ou build de terceiros foi reutilizado.\n'
    printf 'FFmpeg com --enable-gpl: GPL versao 2 ou posterior.\n'
    printf 'x264 e x265 conservam seus direitos autorais e licencas originais.\n'
    printf 'Nao ha transferencia dos direitos desses componentes ao autor do aplicativo.\n'
    printf 'O aplicativo os chama como processos separados; esta nota nao atribui uma licenca ao aplicativo.\n\n'
    printf 'Fontes correspondentes, receitas, patches, configuracao e licencas:\n'
    printf 'https://github.com/luziellacerda/APARADOR-LZ/releases\n'
    printf 'Asset da MESMA versao do instalador: FFmpeg-corresponding-source.tar.xz\n'
    printf 'Mantenha esse arquivo junto da distribuicao. Nao se aplica clausula de proibicao de engenharia reversa aos componentes GPL.\n\n'
    jq -r '.ffmpeg,.x264,.x265 | "Projeto: \(.upstream)\nVersao/commit: \(.version) / \(.commit)\nFonte: \(.url)\nSHA256: \(.sha256)\n"' "$lock"
    printf '\nEste material documenta a compilacao e as licencas; nao e certificacao juridica nem garantia sobre patentes.\n'
    for license in "$bundle"/licenses/*; do
        printf '\n\n================ %s ================\n\n' "$(basename "$license")"
        cat "$license"
    done
} > "$out/docs/TERCEIROS-FFMPEG.txt"
cp "$out/docs/TERCEIROS-FFMPEG.txt" "$bundle/THIRD-PARTY-NOTICES.txt"
{
    printf 'Corresponding source for the FFmpeg binaries shipped with Aparador LZ Games.\n\n'
    printf 'archives/ contains the exact downloaded source archives (verified SHA256 in recipe/dependencies.lock.json).\n'
    printf 'recipe/ contains the actual build script and metadata patch. build-information/ records configure results, toolchain versions and PE imports.\n'
    printf 'Codec implementation sources are unchanged. The x265 archive version metadata is corrected to its actual 4.1 tag; FFmpeg VERSION is copied from RELEASE.\n'
    printf 'To rebuild on Ubuntu 24.04, install the packages listed at the top of recipe/Build-FFmpeg.sh, then run bash recipe/Build-FFmpeg.sh /absolute/new/output.\n'
    printf 'The build script uses the included source archives when run from this bundle. It does not require the application checkout.\n'
    printf 'The system toolchain and Windows system libraries are not included; exact observed toolchain package versions are recorded.\n'
    printf 'Build recipe reproducibility is provided, not a guarantee of bit-for-bit identical binaries across different toolchains.\n'
} > "$bundle/README.txt"
(cd "$out/bin" && sha256sum ffmpeg.exe ffprobe.exe) > "$bundle/build-information/binaries.sha256"
tar -C "$build_root" --sort=name --owner=0 --group=0 --numeric-owner \
    -cJf "$out/sources/FFmpeg-corresponding-source.tar.xz" FFmpeg-corresponding-source
(cd "$out" && sha256sum bin/ffmpeg.exe bin/ffprobe.exe sources/FFmpeg-corresponding-source.tar.xz) > "$out/SHA256SUMS.txt"
printf 'FFmpeg cross-build and corresponding source ready: %s\n' "$out"
