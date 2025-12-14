#!/system/bin/sh
# Kernel Optimizations Service
# VM tuning, I/O optimization, and MGLRU configuration

MODDIR=${0%/*}
LOGFILE=/data/local/tmp/kernel_tweaks.log

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOGFILE
    echo "KERNEL_TWEAKS: $1" > /dev/kmsg
}

# Wait for boot to complete
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done
sleep 10  # Extra delay for system stability

log "Starting kernel optimizations service"

# ============================================
# VM Memory Optimizations
# ============================================

# vfs_cache_pressure: Lower = keep dentries/inodes longer (better for app launches)
# Default: 100, Recommended: 50-80 for mobile
echo 60 > /proc/sys/vm/vfs_cache_pressure
log "vfs_cache_pressure = 60"

# swappiness: Controls anon vs file page eviction balance
# MGLRU formula: gain = { swappiness, 200 - swappiness }
#   0 = only evict file pages (never swap)
#   60 = default, slight file page preference
#   100 = equal weight for anon and file pages
# With ZRAM compression, 100 is reasonable (swap is fast)
echo 100 > /proc/sys/vm/swappiness
log "swappiness = 100 (equal anon/file balance with ZRAM)"

# dirty_ratio: % of RAM for dirty pages before sync write
# Lower = more frequent small writes, better for mobile
echo 15 > /proc/sys/vm/dirty_ratio
log "dirty_ratio = 15"

# dirty_background_ratio: % of RAM before background writeback
echo 5 > /proc/sys/vm/dirty_background_ratio
log "dirty_background_ratio = 5"

# dirty_expire_centisecs: How long dirty data can stay in cache (ms * 10)
# 20 seconds - balance between write coalescing and data safety
echo 2000 > /proc/sys/vm/dirty_expire_centisecs
log "dirty_expire_centisecs = 2000 (20s)"

# dirty_writeback_centisecs: Writeback thread wakeup interval
echo 500 > /proc/sys/vm/dirty_writeback_centisecs
log "dirty_writeback_centisecs = 500 (5s)"

# ============================================
# MGLRU Optimizations (if available)
# ============================================

if [ -d /sys/kernel/mm/lru_gen ]; then
    # min_ttl_ms: Minimum time before pages can be evicted
    # Protects recently accessed pages (reduces thrashing)
    if [ -f /sys/kernel/mm/lru_gen/min_ttl_ms ]; then
        echo 1000 > /sys/kernel/mm/lru_gen/min_ttl_ms
        log "MGLRU min_ttl_ms = 1000"
    fi
    log "MGLRU enabled: $(cat /sys/kernel/mm/lru_gen/enabled)"
fi

# ============================================
# I/O Optimizations
# ============================================

# read_ahead_kb: Prefetch size for sequential reads
# Higher = better for loading images/assets in apps
for queue in /sys/block/sd*/queue /sys/block/dm-*/queue; do
    if [ -d "$queue" ]; then
        # 512KB read-ahead for UFS storage
        echo 512 > "$queue/read_ahead_kb" 2>/dev/null

        # nr_requests: Queue depth (higher = better throughput)
        echo 128 > "$queue/nr_requests" 2>/dev/null

        # iostats: Disable to reduce overhead
        echo 0 > "$queue/iostats" 2>/dev/null
    fi
done
log "I/O: read_ahead=512KB, nr_requests=128, iostats=off"

# ============================================
# Network Optimizations
# ============================================

# TCP optimizations for mobile networks
if [ -f /proc/sys/net/ipv4/tcp_fastopen ]; then
    echo 3 > /proc/sys/net/ipv4/tcp_fastopen
    log "TCP Fast Open enabled (client+server)"
fi

# Set BBR as congestion control (with ACK aggregation backport)
if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
    echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    log "TCP congestion control = bbr"
fi

# Larger TCP buffers for better throughput
echo "4096 87380 6291456" > /proc/sys/net/ipv4/tcp_rmem 2>/dev/null
echo "4096 65536 6291456" > /proc/sys/net/ipv4/tcp_wmem 2>/dev/null
log "TCP buffers optimized"

# ============================================
# Summary
# ============================================

log "Kernel optimizations applied successfully"
log "Parameters: vfs_cache_pressure=60, swappiness=100 (anon=file), read_ahead=512KB"
