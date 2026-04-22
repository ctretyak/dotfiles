#!/bin/bash
# Bootstrap Ansible + Flathub on Fedora Kinoite.
# Kinoite has /usr read-only: use rpm-ostree layering for system packages.
# Flathub is not enabled out of the box — ansible flatpak tasks need it.

set -e

if command -v ansible >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    ansible_ready=1
else
    ansible_ready=0
fi

if [ "$ansible_ready" -eq 0 ]; then
    # Layer ansible + git into the OS image. Requires reboot to take effect
    # on next apply; chezmoi will re-run this script next time.
    sudo rpm-ostree install --idempotent --assumeyes ansible git
    echo
    echo "Ansible/git layered into next deployment."
    echo "Reboot, then re-run 'chezmoi apply' to finish provisioning."
    exit 0
fi

# Enable Flathub (system scope) for subsequent ansible flatpak tasks.
if ! flatpak remotes --system 2>/dev/null | grep -q '^flathub'; then
    sudo flatpak remote-add --if-not-exists \
        flathub https://flathub.org/repo/flathub.flatpakrepo
fi

# Enable podman socket so docker-compose-compatible tooling can connect.
systemctl --user enable --now podman.socket 2>/dev/null || true
