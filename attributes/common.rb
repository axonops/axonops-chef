default['axonops']['skip_system_tuning'] = false

# Skip vm.max_map_count setting (useful when managed elsewhere or no permission)
default['axonops']['skip_vm_max_map_count'] = false

# DEPRECATED: superseded by node['axonops']['disable_swap'].
# vm.swappiness is no longer the swap-disabling mechanism — swap is turned off
# entirely. Setting this to true is still honoured and means "do not touch swap
# on this host" (no swapoff, no /etc/fstab edit, vm.swappiness=1 written
# instead). It will be removed in a future major release.
default['axonops']['skip_vm_swappiness'] = false

# Disable swap entirely (swapoff -a + comment out swap entries in /etc/fstab).
# Set to false to leave swap alone; vm.swappiness=1 is then written instead.
# Always skipped inside containers.
default['axonops']['disable_swap'] = true

# Disable Transparent Huge Pages at the OS level (writes 'never' to
# /sys/kernel/mm/transparent_hugepage/{enabled,defrag} and installs a systemd
# unit so it survives reboot). Always skipped inside containers.
default['axonops']['disable_transparent_hugepages'] = true
