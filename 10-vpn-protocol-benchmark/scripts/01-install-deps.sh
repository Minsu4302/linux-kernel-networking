#!/bin/bash
# 벤치마크에 필요한 패키지 설치
# lab-vm-01, lab-vm-02 동시에 실행
set -e

echo "=== 의존 패키지 설치 ==="
sudo apt-get update -qq
sudo apt-get install -y iperf3 sysstat strongswan strongswan-pki libcharon-extra-plugins
echo ""
echo "설치 완료:"
iperf3 --version | head -1
ipsec --version | head -1
