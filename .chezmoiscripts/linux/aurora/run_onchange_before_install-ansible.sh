#!/bin/bash
# Bootstrap Ansible on Aurora (ublue-os KDE).
# /usr is read-only → use rpm-ostree layering.
#
# Flathub is preconfigured by ublue's flatpak-add-flathub-repos.service
# (see ublue-os/main) so no remote-add here. podman-docker is preinstalled
# in Aurora base, same podman user socket as Kinoite.

set -e

if command -v ansible >/dev/null 2>&1; then
    ansible_ready=1
else
    ansible_ready=0
fi

if [ "$ansible_ready" -eq 0 ]; then
    # Aurora base already has git (pulled in by git-credential-libsecret).
    # Only ansible needs layering.
    sudo rpm-ostree install --idempotent --assumeyes ansible
    echo
    echo "Ansible layered into next deployment."
    echo "Reboot, then re-run 'chezmoi apply' to finish provisioning."
    exit 0
fi

# Enable podman user socket so docker-compose-compatible tooling can connect.
systemctl --user enable --now podman.socket 2>/dev/null || true
