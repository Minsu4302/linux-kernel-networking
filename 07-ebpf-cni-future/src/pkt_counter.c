// XDP 패킷 카운터: 수신 패킷을 IP 프로토콜 번호별로 BPF ARRAY 맵에 집계한다.
// 커널 스택에 진입하기 전에 실행되며, 모든 패킷을 XDP_PASS로 통과시킨다.
#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <bpf/bpf_helpers.h>

struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 256);   /* 프로토콜 번호 0-255 */
    __type(key, __u32);
    __type(value, __u64);
} proto_count SEC(".maps");

SEC("xdp")
int count_packets(struct xdp_md *ctx) {
    void *data     = (void *)(long)ctx->data;
    void *data_end = (void *)(long)ctx->data_end;

    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;
    /* IPv4 이외(ARP, IPv6 등)는 그냥 통과 */
    if (eth->h_proto != __constant_htons(0x0800))
        return XDP_PASS;

    struct iphdr *ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end)
        return XDP_PASS;

    __u32 proto = ip->protocol;
    __u64 *cnt = bpf_map_lookup_elem(&proto_count, &proto);
    if (cnt)
        __sync_fetch_and_add(cnt, 1);

    return XDP_PASS;
}

char LICENSE[] SEC("license") = "GPL";
