#!/system/bin/sh
# Kernel Tweaks - Early init
# Apply critical settings before boot completes

MODDIR=${0%/*}

# Early VM tweaks (if writable at this stage)
echo 60 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
echo 100 > /proc/sys/vm/swappiness 2>/dev/null

echo "KERNEL_TWEAKS: Early init applied" > /dev/kmsg
