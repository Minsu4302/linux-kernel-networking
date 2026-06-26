#!/bin/bash
# XDP 프로그램 컴파일 — lab-vm-02(방어 노드)에서 실행
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_DIR/src/xdp_drop.c"
BUILD="$REPO_DIR/build"
mkdir -p "$BUILD"

ARCH=$(uname -m)
HEADERS="-I/usr/include/${ARCH}-linux-gnu"

echo "=== XDP 프로그램 컴파일 ==="
clang -O2 -g -target bpf $HEADERS -c "$SRC" -o "$BUILD/xdp_drop.o"
echo "  완료: $BUILD/xdp_drop.o ($(du -h $BUILD/xdp_drop.o | cut -f1))"

echo ""
echo "=== BTF 섹션 확인 ==="
llvm-objdump -h "$BUILD/xdp_drop.o" | grep -E "xdp|maps|BTF|license"
echo ""
echo "빌드 성공. 다음 단계: 04-xdp-load.sh"
