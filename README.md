# machine-setup

Automated dev environment bootstrap for Pop!_OS / Ubuntu and macOS. One command installs everything.

## Quick Start

```bash
git clone <your-repo-url> ~/./_workspace/projects/machine-setup
cd ~/./_workspace/projects/machine-setup
bash bootstrap.sh
```

Or without prompts:

```bash
bash bootstrap.sh --yes
```

## What Gets Installed

| Category | Linux (Pop!_OS / Ubuntu) | macOS |
|----------|-------------------------|-------|
| System packages | `apt` | Homebrew formulae |
| GUI apps | apt repos + Flatpak + AppImage | Homebrew casks |
| Dev tools | `mise` | `mise` |
| Shell | Zsh (via apt) | Zsh (pre-installed) |
| Dotfiles | GNU Stow | GNU Stow |
| SSH server | openssh-server config | skip |
| CapsLock/Esc swap | COSMIC `xkb_config` | `hidutil` + LaunchAgent |

### Dev Tools (via mise)

All installed cross-platform via [mise](https://mise.jdx.dev/):

- **Runtimes**: Node LTS, Python 3.12
- **Shell tools**: fzf, zoxide, ripgrep, bat, fd, eza, delta
- **Git**: lazygit, delta
- **Prompt**: starship
- **Utilities**: tldr, jq, yq, uv, ruff

## Usage

### Full setup

```bash
make install        # With confirmation prompt
make install-yes    # Without prompts
```

### Partial setup

```bash
bash bootstrap.sh --only mise       # Only install mise tools
bash bootstrap.sh --only dotfiles   # Only stow dotfiles
bash bootstrap.sh --list            # List all available scripts
```

### Dotfile management

```bash
make sync                          # Pull latest + re-stow + mise install
make check                         # Show symlink drift
make add PKG=zsh FILE=~/.zshrc    # Add a file to a stow package
dotup                              # Same as make sync
dotcheck                           # Same as make check
dotadd zsh ~/.zshrc                # Same as make add
```

### Testing

```bash
make test           # Run all verification checks (12-verify.sh)
make test-commands  # Check required commands exist
make test-dotfiles  # Check dotfile symlinks
make test-services  # Check SSH, Docker, etc.
```

## Repo Structure

```
machine-setup/
├── bootstrap.sh              # Single entry point
├── Makefile                  # Convenience targets
├── config/
│   ├── packages.toml         # All package lists
│   └── appimages.toml        # Linux AppImage definitions
├── scripts/
│   ├── _lib.sh               # Shared utilities
│   ├── 01-system-update.sh
│   ├── 02-homebrew.sh
│   ├── 03-apt-repos.sh       # Linux only
│   ├── 04-apt-packages.sh    # Linux only
│   ├── 05-flatpak.sh         # Linux only
│   ├── 06-appimages.sh       # Linux only
│   ├── 07-mise.sh
│   ├── 08-shell-setup.sh
│   ├── 09-dotfiles.sh
│   ├── 10-ssh-server.sh      # Linux only
│   ├── 11-desktop-settings.sh
│   └── 12-verify.sh
├── bin/
│   ├── dotup                 # Pull + re-stow dotfiles
│   ├── dotadd                # Add file to stow package
│   └── dotcheck              # Check symlink drift
├── dotfiles/                 # GNU Stow packages
│   ├── zsh/
│   ├── git/
│   ├── starship/
│   ├── mise/
│   ├── bat/
│   └── lazygit/
└── tests/
    ├── test-commands.sh
    ├── test-dotfiles.sh
    └── test-services.sh
```

## Configuration

Edit `config/packages.toml` to add or remove packages:

```toml
[apt]
packages = ["my-new-package"]

[flatpak]
packages = ["com.example.App"]

[brew]
casks = ["my-mac-app"]
```

Edit `config/appimages.toml` to add Linux AppImages:

```toml
[myapp]
url = "https://example.com/MyApp.AppImage"
name = "My App"
categories = "Utility;"
```

Edit `dotfiles/mise/.config/mise/config.toml` to add dev tools:

```toml
[tools]
"ubi:owner/repo" = "latest"
```

## After Setup

1. **Restart your shell**: `exec zsh` or open a new terminal
2. **Configure git identity**:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```
3. **Connect via SSH from another machine** (Linux):

   Password auth is disabled by default. To copy your key over:
   ```bash
   # On this PC — temporarily allow password auth
   sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' \
       /etc/ssh/sshd_config.d/99-custom.conf
   sudo systemctl reload ssh

   # On the other machine — copy your public key
   ssh-copy-id <your-username>@<this-pc-ip>

   # On this PC — disable password auth again
   sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' \
       /etc/ssh/sshd_config.d/99-custom.conf
   sudo systemctl reload ssh
   ```

   Or add the key manually on this PC:
   ```bash
   echo "<paste your public key>" >> ~/.ssh/authorized_keys
   ```
4. **Verify everything**: `make test`

## Design Principles

- **Idempotent**: Safe to run multiple times — checks before acting
- **Cross-platform**: Single codebase for Linux and macOS
- **No magic**: Plain bash, GNU Stow for dotfiles, mise for tools
- **TOML config**: All packages in one structured config file
- **Drop-in SSH**: `/etc/ssh/sshd_config.d/99-custom.conf` survives upgrades
