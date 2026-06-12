# bonfire

[![ci](https://github.com/haoyu-zc/bonfire/actions/workflows/ci.yml/badge.svg)](https://github.com/haoyu-zc/bonfire/actions/workflows/ci.yml)

Automated dev environment bootstrap for Pop!_OS / Ubuntu and macOS.

It runs in two modes, for a shared multi-user machine:

- **Admin / full setup** (`--admin`) — system-wide provisioning done **once** by the
  machine admin: apt repos + packages, Flatpak apps, SSH server, Homebrew, desktop
  settings, plus every per-user step. Also the mode for macOS / single-user machines.
- **Per-user** (default, no flag) — what each additional lab user runs in their own
  account: mise + CLI tools, dotfiles, zsh as their default shell, AppImages, and their
  `~/.ssh` scaffold. No sudo needed; assumes the box was already `--admin`-provisioned
  (so the shared apt/system tools — stow, zsh, gh — already exist).

## Quick Start

```bash
git clone git@github.com:haoyu-zc/bonfire.git ~/bonfire   # any path you like
cd ~/bonfire

# First time on a machine (admin) — and all macOS / single-user setups:
bash bootstrap.sh --admin --dry-run --yes   # preview
bash bootstrap.sh --admin                   # run it (asks for confirmation)

# Each additional lab user, in their own account — per-user dev env only:
bash bootstrap.sh
```

The repo derives its own location at runtime, so you can clone it anywhere — no
hardcoded paths to update. `--dry-run` is a *package-install preview*: it wraps
`apt install`, `flatpak install`, `mise install`, `stow --restow`, and the
stow conflict-backup `mv` via `scripts/_lib.sh:run()` and prints them as
`[dry-run]` markers instead of executing. Other bootstrap steps still run —
`apt-get update`, apt-repo key writes, Homebrew updates, AppImage downloads,
SSH server config, desktop/keyboard settings, the `setup.log` itself. Use
`--only` to scope what runs (e.g., `--dry-run --only "04-apt-packages 07-mise
09-dotfiles"`). Add `--yes` to skip prompts.

### Run modes — which steps run

`--admin` runs all 12 steps. The default (per-user) run executes only the per-user steps
and skips the system parts of mixed steps:

- **Admin-only** (skipped without `--admin`): `01-system-update`, `02-homebrew`,
  `03-apt-repos`, `04-apt-packages`, `05-flatpak`, `11-desktop-settings`.
- **Per-user** (always run): `06-appimages`, `07-mise`, `09-dotfiles`, the `chsh` in
  `08-shell-setup`, the `~/.ssh` scaffold in `10-ssh-server`, and `12-verify`.

`bash bootstrap.sh --list` marks the admin-only steps. A per-user step that needs an
admin-provided tool (e.g. `stow`, or `gh`/a GitHub token) stops with instructions if it's
missing — run `--admin` (or ask the admin), then resume with `--from <step>`.

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

All installed cross-platform via [mise](https://mise.jdx.dev/) — see
`dotfiles/mise/.config/mise/config.toml` for the source of truth.

- **Runtimes**: Node LTS, Python 3.12, Neovim stable (with [LazyVim](https://www.lazyvim.org/))
- **Shell tools**: fzf, zoxide, ripgrep, bat, fd, eza, starship, jq, yq
- **Git**: lazygit, delta, git-lfs
- **Python**: uv, ruff
- **TUI / terminal**: zellij, gum, yazi
- **Modern coreutils**: procs (ps), dust (du), duf (df), btop (top), sd (sed), hyperfine (benchmarking)

Shell-facing tools (`starship`, `fzf`, `zoxide`, `eza`, `bat`) are pinned to
major versions so a fresh-machine bootstrap a year from now won't pull a
surprise breaking 2.0 that changes your daily-driver behavior. Fast-moving
tools (`ruff`, `uv`) stay on `"latest"` to get fixes. (`gh` is installed
system-wide via apt instead — see below.)

> `tldr` (tealdeer) is **not** managed by mise. On macOS it's a Homebrew
> formula (`[brew] formulae` in `config/packages.toml`); on Linux,
> `scripts/07-mise.sh` downloads the latest binary directly from
> tealdeer's GitHub releases (the apt-packaged version 1.6.1 has a
> hardcoded broken cache URL).

### apt packages (Linux)

Defined in `config/packages.toml [apt] packages`. Three third-party apt repos
(`[apt.repos.google-chrome]`, `[apt.repos.vscode]`, `[apt.repos.github-cli]`)
are wired in `scripts/03-apt-repos.sh` before install.

- **Build essentials**: build-essential, curl, wget, git, stow, unzip, zip,
  ca-certificates, gnupg, software-properties-common
- **Clipboard**: xclip, wl-clipboard
- **Shell**: zsh, zsh-autosuggestions, zsh-syntax-highlighting
- **Dev libraries** (for compiling Python etc.): libssl-dev, libffi-dev,
  zlib1g-dev, libreadline-dev, libsqlite3-dev, libncursesw5-dev, liblzma-dev
- **System tools**: htop, btop, tree, ncdu
- **Containers**: podman, podman-compose, buildah
- **From third-party repos**: google-chrome-stable, code (VS Code), gh (GitHub
  CLI — installed before mise; `07-mise.sh` reads `gh auth token` to give mise a
  GitHub token. If no token is present the bootstrap **stops with instructions**
  rather than hitting the API rate limit — authenticate gh (or set
  `GITHUB_TOKEN`) and resume with `bash bootstrap.sh --from 07-mise.sh`)

### Flatpak apps (Linux)

Defined in `config/packages.toml [flatpak] packages`. Flathub remote is
added automatically by `scripts/05-flatpak.sh`.

- Obsidian (`md.obsidian.Obsidian`)
- Slack (`com.slack.Slack`)

### AppImages (Linux)

Defined in `config/appimages.toml`. Each AppImage is downloaded into
`~/.local/share/AppImages/`, made executable, and given a `.desktop` entry by
`scripts/06-appimages.sh`.

- Snipaste — screenshot + annotation tool (`2.11.3-x86_64`)

### Homebrew formulae (Linux + macOS)

Defined in `config/packages.toml [brew] formulae`. Installed by
`scripts/02-homebrew.sh` on both platforms.

- stow, zsh-autosuggestions, zsh-syntax-highlighting, tealdeer

### Homebrew casks (macOS only)

Defined in `config/packages.toml [brew] casks`.

- **Browsers**: google-chrome
- **Editors**: visual-studio-code, obsidian
- **Productivity**: raycast, rectangle, slack
- **Screenshot**: snipaste
- **Terminal**: wezterm
- **Keyboard remap**: karabiner-elements
- **Containers**: podman-desktop

## Usage

### Full setup

```bash
make install        # With confirmation prompt
make install-yes    # Without prompts
```

### Partial setup

```bash
bash bootstrap.sh --only mise                    # Run only the mise script (keyword match)
bash bootstrap.sh --only "07-mise 09-dotfiles"   # Multiple keywords
bash bootstrap.sh --from 09                      # Resume from step 09 onwards
bash bootstrap.sh --dry-run --yes                # Preview package-install steps (see below)
bash bootstrap.sh --list                         # List all available scripts
```

`--dry-run` wraps the package-install mutators (apt install, flatpak install,
mise install, stow restow, conflict-backup `mv`) via `scripts/_lib.sh:run()`
and prints them as `[dry-run] <cmd>` instead of executing. Idempotency checks
(`apt_installed`, `flatpak_installed`, etc.) still run, so the preview is
accurate for those mutators. Real runs print the same lines with a `[mutate]`
prefix — CI uses this to assert idempotency: a second bootstrap should
produce zero new `[mutate]` markers (excluding externally-idempotent re-runs
like `mise install` and `stow --restow`, which CI filters out).

It's a preview of the *package-install layer*, not the full bootstrap. Other
steps (`apt-get update`, apt-repo / GPG-key wiring, Homebrew updates, AppImage
downloads, SSH server config, desktop/keyboard settings) still execute under
dry-run. Combine with `--only` to scope sharply, e.g. `--dry-run --only
"04-apt-packages 09-dotfiles"` previews what apt would install and where stow
would link, without touching the rest.

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
bonfire/
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
│   ├── dotup                 # Pull + re-stow dotfiles (--full delegates to dotsync)
│   ├── dotsync               # Full sync: pull + packages + mise prune
│   ├── pkgaudit              # Read-only drift report
│   ├── dotadd                # Add file to stow package
│   └── dotcheck              # Check symlink drift
├── dotfiles/                 # GNU Stow packages
│   ├── zsh/
│   ├── git/
│   ├── starship/
│   ├── mise/
│   ├── bat/
│   ├── lazygit/
│   └── nvim/                 # Neovim + LazyVim config
└── tests/
    ├── test-commands.sh
    ├── test-dotfiles.sh
    └── test-services.sh
```

## Managing Packages

### Quick reference

| Command | What it does |
|---------|-------------|
| `make sync` | Pull latest + re-stow dotfiles + `mise install` |
| `make sync-all` | Everything in `sync`, plus re-run all install scripts + `mise prune` |
| `make audit` | Read-only drift report: missing vs extra per manager |
| `dotup --full` | Same as `make sync-all` |

### Adding a package

Edit the relevant config file, then run `make sync-all`.

| Manager | Config file | Section/key |
|---------|------------|-------------|
| apt | `config/packages.toml` | `[apt] packages` |
| Flatpak | `config/packages.toml` | `[flatpak] packages` |
| Homebrew formula | `config/packages.toml` | `[brew] formulae` |
| Homebrew cask (macOS) | `config/packages.toml` | `[brew] casks` |
| AppImage (Linux) | `config/appimages.toml` | new `[key]` section |
| Dev tool (mise) | `dotfiles/mise/.config/mise/config.toml` | `[tools]` |

Example — add an apt package:

```toml
# config/packages.toml
[apt]
packages = [
    # ... existing packages ...
    "my-new-package",
]
```

Then:

```bash
make sync-all
```

### Removing a package

1. Delete the entry from the config file.
2. Uninstall manually — auto-removal is intentionally not implemented to avoid
   accidental data loss.

| Manager | Uninstall command |
|---------|------------------|
| apt | `sudo apt remove <package>` |
| Flatpak | `flatpak uninstall <app-id>` |
| Homebrew formula | `brew uninstall <formula>` |
| Homebrew cask | `brew uninstall --cask <cask>` |
| AppImage | `rm ~/.local/share/AppImages/<file>.AppImage` |
| mise | Remove from config then `make sync-all` — `mise prune` removes it automatically |

### Auditing drift

```bash
make audit
```

Prints a per-manager report of:
- **MISSING** — in config but not installed
- **EXTRA** — installed but not in config (flatpak, brew, mise only; apt extras
  are skipped as base system packages are too numerous to track)

Run this after switching machines or pulling someone else's changes to see what
still needs to be installed.

## After Setup

1. **Restart your shell**: `exec zsh` or open a new terminal
2. **Verify your git identity**: the dotfiles step prompts for your name/email
   and writes them to `~/.gitconfig.local` (untracked, per-user). Check with:
   ```bash
   git config user.name && git config user.email
   ```
   To change it later, edit `~/.gitconfig.local` or run:
   ```bash
   git config --file ~/.gitconfig.local user.name  "Your Name"
   git config --file ~/.gitconfig.local user.email "you@example.com"
   ```
   > Don't use `git config --global …` — `~/.gitconfig` is a symlink into this
   > repo, so a global write would modify the tracked dotfile and leak your
   > identity into the repo. The stowed `.gitconfig` carries no identity; it
   > `[include]`s `~/.gitconfig.local` instead.
   >
   > **Upgrading an older clone?** If you previously ran `git config --global`,
   > that write landed in the symlinked repo file, so `git status` in the repo
   > shows `dotfiles/git/.gitconfig` as modified and `git pull` will conflict.
   > Recover by lifting your identity out and discarding the tracked edit (run
   > these from the repo directory; read with `--global` to get the leaked
   > value, not a repo-local override):
   > ```bash
   > cd ~/bonfire    # or wherever you cloned it
   > git config --file ~/.gitconfig.local user.name  "$(git config --global user.name)"
   > git config --file ~/.gitconfig.local user.email "$(git config --global user.email)"
   > git checkout -- dotfiles/git/.gitconfig
   > git pull
   > ```
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

## Development

Linting runs via [pre-commit](https://pre-commit.com): shellcheck + shfmt for
bash, actionlint for `.github/workflows/*.yml`, plus a few cheap built-ins
(trailing whitespace, EOF newline, yaml/json validation).

Set it up once per clone:

```bash
make pre-commit-install   # installs pre-commit (pip --user) and the git hook
make pre-commit           # lint everything right now
```

After install, `git commit` will refuse commits that fail the checks.

## Design Principles

- **Idempotent**: Safe to run multiple times — checks before acting
- **Cross-platform**: Single codebase for Linux and macOS
- **No magic**: Plain bash, GNU Stow for dotfiles, mise for tools
- **TOML config**: All packages in one structured config file
- **Drop-in SSH**: `/etc/ssh/sshd_config.d/99-custom.conf` survives upgrades
