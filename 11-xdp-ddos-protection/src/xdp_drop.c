#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

/* 차단할 소스 IP 해시맵: key=IPv4(네트워크 바이트 오더), value=드롭 횟수 */
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 1024);
    __type(key, __u32);
    __type(value, __u64);
} blocklist SEC(".maps");

/* 전체 통계: [0]=수신 총량, [1]=드롭 총량 */
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 2);
    __type(key, __u32);
    __type(value, __u64);
} counters SEC(".maps");

SEC("xdp")
int xdp_ddos_filter(struct xdp_md *ctx)
{
    void *data_end = (void *)(long)ctx->data_end;
    void *data     = (void *)(long)ctx->data;

    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;

    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS;

    struct iphdr *ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end)
        return XDP_PASS;

    /* 수신 카운터 */
    __u32 idx = 0;
    __u64 *cnt = bpf_map_lookup_elem(&counters, &idx);
    if (cnt) __sync_fetch_and_add(cnt, 1);

    /* 블랙리스트 확인 → 차단 */
    __u64 *drop_cnt = bpf_map_lookup_elem(&blocklist, &ip->saddr);
    if (drop_cnt) {
        __sync_fetch_and_add(drop_cnt, 1);
        idx = 1;
        cnt = bpf_map_lookup_elem(&counters, &idx);
        if (cnt) __sync_fetch_and_add(cnt, 1);
        return XDP_DROP;
    }

    return XDP_PASS;
}

char LICENSE[] SEC("license") = "GPL";
