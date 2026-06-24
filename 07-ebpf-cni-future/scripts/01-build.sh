#!/bin/bash
# XDP 프로그램 빌드: C 소스를 BPF 바이트코드(.o)로 컴파일한다.
# lab-vm-01에서 실행
#
# 사전 조건:
#   sudo apt install -y clang llvm libbpf-dev libelf-dev
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/../src"
BUILD_DIR="$HOME/ebpf-lab"
HEADERS="-I/usr/include/$(uname -m)-linux-gnu"

echo "=== XDP 프로그램 빌드 ==="
mkdir -p "$BUILD_DIR"

for src in pkt_counter drop_icmp; do
    echo "  컴파일: $src.c"
    clang -O2 -g -target bpf $HEADERS \
        -c "$SRC_DIR/$src.c" -o "$BUILD_DIR/$src.o"
done

echo ""
echo "=== 빌드 결과 ==="
ls -lh "$BUILD_DIR"/*.o
echo ""
echo "BTF 섹션 포함 확인:"
llvm-readelf --section-headers "$BUILD_DIR/pkt_counter.o" | grep BTF | head -3
