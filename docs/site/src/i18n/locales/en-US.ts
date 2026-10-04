import type { DocPage, DocsContent, PageId } from "../types";

const TRANSCRIPT = [
  "➜ ~/codes/dottod  ./bin/bootstrap.sh",
  "▶ Bootstrap starting (10 task(s))",
  "  ✔ shell: PASS",
  "  ✔ fonts: PASS",
  "  ✔ vim: PASS",
  "  ✔ neovim: PASS",
  "  ✔ gitconfig: PASS",
  "  ✔ ssh: PASS",
  "  ✔ tools: PASS",
  "  ✔ cargo: PASS",
  "  ✔ bun: PASS",
  "  ✔ Bootstrap complete",
];

const pages: Record<PageId, DocPage> = {
  overview: {
    id: "overview",
    title: "Overview",
    summary: "What dottod is, why plain bash, and the tasks at a glance.",
    hero: {
      eyebrow: "dottod",
      title: "dottod",
      subtitle: "Rebuild a Debian workstation with one plain-bash command.",
      ctaLabel: "Get started",
      ctaHref: "/start",
      transcript: TRANSCRIPT,
    },
    sections: [
      {
        id: "what",
        heading: "What it is",
        blocks: [
          {
            kind: "p",
            text: "dottod is a personal dotfiles and workstation bootstrap for Debian. One entry point — bin/bootstrap.sh — runs twelve idempotent tasks: shell, fonts, editors, container runtime, terminal, CLI tooling, and GitHub SSH. Every task checks before it acts, backs up what it replaces, and reports PASS or FAIL with a per-task log.",
          },
        ],
      },
      {
        id: "why-bash",
        heading: "Plain bash, on purpose",
        blocks: [
          {
            kind: "p",
            text: "No plugins, no frameworks, no prompt stack. zsh, oh-my-zsh and spaceship were removed after they stalled interactive terminals; the replacement is one bashrc with an exit-aware prompt, git context, and small utilities. One entry point, one log per task, and every task safe to run twice.",
          },
        ],
      },
      {
        id: "tasks-glance",
        heading: "Tasks at a glance",
        blocks: [
          {
            kind: "table",
            headers: ["Task", "Does"],
            rows: [
              ["shell", "bash as login shell, links ~/.bashrc"],
              ["fonts", "Nerd Fonts, user-level"],
              ["vim", "vim + vim-plug + plugins"],
              ["neovim", "Neovim ≥ 0.11, lazy.nvim, 16 pinned plugins"],
              ["container", "Podman default, Docker alternative"],
              ["zed", "Zed editor (GUI, opt-in)"],
              ["ghostty", "Ghostty terminal (GUI, opt-in)"],
              ["gitconfig", "Git identity"],
              ["ssh", "GitHub host merge + ed25519 key"],
              [
                "tools",
                "lazygit, lazydocker, k9s, btop, httpie, bat, resterm, xclip, chafa, fzf, gh",
              ],
              ["cargo", "Rust toolchain via rustup"],
              ["bun", "Bun runtime + devcontainer CLI"],
            ],
          },
        ],
      },
    ],
  },
  start: {
    id: "start",
    title: "Getting started",
    summary: "Clone, run, verify — and recover after a reset.",
    sections: [
      {
        id: "install",
        heading: "Install and run",
        blocks: [
          {
            kind: "code",
            lang: "bash",
            caption: "Clone and bootstrap",
            code: "git clone https://github.com/lucasvmigotto/dottod.git\ncd dottod\n./bin/bootstrap.sh",
          },
          {
            kind: "p",
            text: "You need Debian (or Debian-based) with apt, plus sudo or doas. If sudo is not passwordless you will be asked once; otherwise run as root. GUI tasks (zed, ghostty) are skipped by default — pass --ui to include them.",
          },
        ],
      },
      {
        id: "verify",
        heading: "Verify",
        blocks: [
          {
            kind: "p",
            text: "The bootstrap ends with a PASS/FAIL summary. Each task also writes /tmp/dottod/<task>.log in quiet mode (--verbose streams instead). Re-run it any time: every task checks before it acts.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Re-run safely",
            code: "./bin/bootstrap.sh",
          },
        ],
      },
      {
        id: "recover",
        heading: "Recover after a reset",
        blocks: [
          {
            kind: "ol",
            items: [
              "Reinstall Debian and clone this repository.",
              "Run ./bin/bootstrap.sh (add GIT_NAME/GIT_EMAIL for a non-interactive gitconfig).",
              "For one failed task only: ./bin/bootstrap.sh --only <task>, then read /tmp/dottod/<task>.log.",
              "Neovim below 0.11: re-run with _DOT_NVIM_ALLOW_TARBALL=1 to heal via the verified tarball.",
            ],
          },
        ],
      },
    ],
  },
  tasks: {
    id: "tasks",
    title: "Tasks",
    summary:
      "The twelve bootstrap tasks: what each does and whether it is safe to re-run.",
    sections: [
      {
        id: "all",
        heading: "All tasks",
        blocks: [
          {
            kind: "table",
            headers: ["Task", "Safe to re-run", "Needs"],
            rows: [
              ["shell", "Yes", "apt (git, bash)"],
              ["fonts", "Yes", "nothing when present"],
              ["vim", "Yes", "network for missing plugins only"],
              ["neovim", "Yes", "apt or tarball (0.11+)"],
              ["container", "Yes", "apt on first run"],
              ["zed", "Yes (opt-in)", "network"],
              ["ghostty", "Yes (opt-in)", "network"],
              ["gitconfig", "Yes", "GIT_NAME/GIT_EMAIL once"],
              ["ssh", "Yes", "nothing (keygen once)"],
              ["tools", "Yes", "apt + GitHub releases"],
              ["cargo", "Yes", "network once"],
              ["bun", "Yes", "network once"],
            ],
          },
          {
            kind: "p",
            text: "Open a task below for flags, environment, and troubleshooting. GUI tasks never run unless --ui is passed.",
          },
        ],
      },
    ],
  },
  "task-shell": {
    id: "task-shell",
    title: "shell",
    summary: "bash as login shell; links ~/.bashrc. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Ensures bash is installed and set as the login shell (chsh, skipped when already bash), then links config/.custom.bashrc to ~/.bashrc with backup. The bashrc carries an exit-aware prompt, git branch/dirty segment, tool PATH entries, and small utilities (mkcd, extract, ff, gr, gcl) plus the ctr container dispatcher.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Run it alone",
            code: "./bin/bootstrap.sh --only shell",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotent?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Yes. chsh is skipped when bash is already the shell; an already-correct link is a no-op without extra backups.",
          },
        ],
      },
    ],
  },
  "task-fonts": {
    id: "task-fonts",
    title: "fonts",
    summary: "Nerd Fonts, user-level. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Installs FiraCode, FiraMono, RobotoMono, NerdFontsSymbolsOnly and ZedMono into ~/.local/share/fonts (override with names on the command line or _DOT_NERDFONT_VERSION). Installed fonts are detected with fc-list and skipped — nothing re-downloads.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Run it alone",
            code: "./bin/bootstrap.sh --only fonts\n./bin/fonts.sh FiraCode ZedMono",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotent?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Yes, and sudo-free when curl, fontconfig and unzip are present: packages install only for actually-missing prerequisites. Fonts never touch GNOME settings — only the terminal uses them.",
          },
          {
            kind: "table",
            headers: ["Variable", "Default"],
            rows: [
              ["_DOT_NERDFONT_VERSION", "v3.4.0"],
              ["_DOT_NERDFONT_GLOBAL_INSTALL", "0 (user-level)"],
            ],
          },
        ],
      },
    ],
  },
  "task-vim": {
    id: "task-vim",
    title: "vim",
    summary: "vim + vim-plug + plugins. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Installs vim, fetches vim-plug (with retries), links ~/.vimrc, then runs PlugInstall only for plugins missing under ~/.vim/plugged. Coexists with Neovim; never replaced by it.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Run it alone",
            code: "./bin/bootstrap.sh --only vim",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotent?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Yes. vim-plug and present plugins are skipped; a correct link is a no-op.",
          },
        ],
      },
    ],
  },
  "task-neovim": {
    id: "task-neovim",
    title: "neovim",
    summary:
      "Neovim ≥ 0.11 with a zero-dependency lazy.nvim config. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Installs Neovim (apt when the candidate is ≥ 0.11, otherwise fails with instructions), links ~/.config/nvim to the repo (existing configs are backed up, never deleted), and lets lazy.nvim sync 16 pinned plugins on first launch. Profiles via DOTTOD_NVIM_PROFILE: minimal, terminal, development (default), full.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Heal via tarball when apt is too old",
            code: "_DOT_NVIM_ALLOW_TARBALL=1 ./bin/neovim.sh",
          },
        ],
      },
      {
        id: "troubleshoot",
        heading: "Troubleshooting",
        blocks: [
          {
            kind: "table",
            headers: ["Symptom", "Fix"],
            rows: [
              [
                "0.10.4 via apt is below the minimum",
                "Re-run with _DOT_NVIM_ALLOW_TARBALL=1",
              ],
              ["Tarball did not yield nvim", "Check ~/.local/bin is on PATH"],
              [
                "An old nvim shadows the new one",
                "Healing links ~/.local/bin first; open a login shell",
              ],
            ],
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotent?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Yes. A compatible binary skips; a correct link is a no-op without extra backups. :checkhealth dottod reports profile and tools.",
          },
        ],
      },
    ],
  },
  "task-container": {
    id: "task-container",
    title: "container",
    summary: "Podman by default, Docker when selected. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Resolves podman, docker or auto (never silently switching an explicit choice), ensures rootless Podman (uidmap + subuid/subgid ranges) or delegates to the Docker installer. container.sh status prints the selection/installation/usability report without changing anything.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Select and inspect",
            code: "./bin/bootstrap.sh --runtime docker --only container\n./bin/container.sh status",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotent?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Yes. A usable engine is a no-op with zero privilege calls; subuid ranges are allocated once. Never migrates or destroys the other runtime.",
          },
        ],
      },
    ],
  },
  "task-zed": {
    id: "task-zed",
    title: "zed",
    summary: "Zed editor, user-level. Opt-in with --ui. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Downloads the official installer and runs it from a file (never pipe-to-shell) into ~/.local/bin. Channel and version pass through as the installer expects.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Run it alone",
            code: "./bin/bootstrap.sh --ui --only zed",
          },
        ],
      },
      {
        id: "env",
        heading: "Environment",
        blocks: [
          {
            kind: "table",
            headers: ["Variable", "Default"],
            rows: [
              ["_DOT_ZED_CHANNEL", "stable"],
              ["_DOT_ZED_VERSION", "latest"],
            ],
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotent?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Yes. A present zed skips without network. Skipped entirely without --ui.",
          },
        ],
      },
    ],
  },
  "task-ghostty": {
    id: "task-ghostty",
    title: "ghostty",
    summary: "Ghostty terminal + default. Opt-in with --ui. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Runs the ghostty-ubuntu installer from a downloaded file (never piped into a privileged shell), then sets Ghostty as the GNOME default terminal and x-terminal-emulator alternative.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Run it alone",
            code: "./bin/bootstrap.sh --ui --only ghostty",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotent?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Yes. A present ghostty skips the install; the default-terminal setting re-applies. Skipped entirely without --ui.",
          },
        ],
      },
    ],
  },
  "task-gitconfig": {
    id: "task-gitconfig",
    title: "gitconfig",
    summary: "Git identity. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Sets user.name and user.email from GIT_NAME/GIT_EMAIL, the existing global config, or one TTY prompt — then writes ~/.gitconfig (backed up first). Matching values are left untouched: no backup, no rewrite.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Non-interactive",
            code: 'GIT_NAME="Your Name" GIT_EMAIL="you@example.com" ./bin/gitconfig.sh',
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotent?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Yes. Identical values skip silently; changed values back up and rewrite, then verify by reading back.",
          },
        ],
      },
    ],
  },
  "task-ssh": {
    id: "task-ssh",
    title: "ssh",
    summary: "GitHub host merge + ed25519 key. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Merges the required github.com options from config/.ssh.config into ~/.ssh/config (missing keys only; your values are never overwritten; byte-identical reruns), then generates an ed25519 key at ~/.ssh/github when neither half exists — never regenerating.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Run it alone",
            code: "./bin/bootstrap.sh --only ssh",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotent?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Yes. Complete configs and existing keys are untouched; exactly one Host github.com stanza, validated with ssh -G.",
          },
        ],
      },
    ],
  },
  "task-tools": {
    id: "task-tools",
    title: "tools",
    summary: "Terminal toolbox + GitHub CLI. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Installs btop, httpie, chafa, xclip, bat, jq, curl, tar, ca-certificates, lsof and fzf from apt (skipped when all present), gh from its official apt repository (signed keyring), and lazygit, lazydocker, k9s and resterm from GitHub releases — sha256-verified against the release API digest, with warn-and-proceed when unpublished.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Run it alone",
            code: "./bin/bootstrap.sh --only tools",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotent?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Yes. Every tool probes PATH-or-destination before downloading; apt is skipped wholesale when satisfied.",
          },
        ],
      },
    ],
  },
  "task-cargo": {
    id: "task-cargo",
    title: "cargo",
    summary: "Rust toolchain via rustup. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Downloads rustup-init and runs it from a file with --no-modify-path (installers never touch ~/.bashrc; PATH comes from the repo bashrc), stable toolchain, minimal profile. cargo.sh status prints a report without changing anything.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Pin a toolchain",
            code: "_DOT_RUSTUP_TOOLCHAIN=1.98.0 ./bin/cargo.sh",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotent?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Yes. A working cargo skips; a finished run is verified by executing the planted binary.",
          },
        ],
      },
    ],
  },
  "task-bun": {
    id: "task-bun",
    title: "bun",
    summary: "Bun runtime + devcontainer CLI. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Installs the single bun binary from the official release zip (sha256-verified, warns when no digest is published) into ~/.local/bin — never bun's installer script, which would append to ~/.bashrc. Then installs the devcontainer CLI with bun install --global (needs node; installed via apt only when missing).",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Pin a version",
            code: "_DOT_BUN_VERSION=bun-v1.2.0 ./bin/bun.sh",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotent?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Yes. Present binaries skip; checksum mismatches fail loudly with nothing installed.",
          },
        ],
      },
    ],
  },
  "guide-shell": {
    id: "guide-shell",
    title: "Shell prompt",
    summary: "The bash prompt, utilities, and PATH layout.",
    sections: [
      {
        id: "prompt",
        heading: "The prompt",
        blocks: [
          {
            kind: "p",
            text: "An exit-aware arrow (green on success, red on failure), the current directory, and git branch with a dirty marker — per-repo opt-out with git config dottod.hide-dirty 1. No plugins, no frameworks; PROMPT_COMMAND does the work.",
          },
        ],
      },
      {
        id: "path",
        heading: "PATH layout",
        blocks: [
          {
            kind: "p",
            text: "~/.local/bin first, then ~/.opencode/bin, ~/.bun/bin and ~/.cargo/bin when they exist. Prepended once per shell — re-sourcing never duplicates entries.",
          },
        ],
      },
      {
        id: "utils",
        heading: "Utilities",
        blocks: [
          {
            kind: "p",
            text: "scripts/.*.sh libraries load aliases (lll, git shortcuts), functions (mkcd, extract, ff, gr, psg, port, serve, gcl) and the ctr container dispatcher. Only the hidden library files load — scripts/*.sh are programs and are never sourced.",
          },
        ],
      },
    ],
  },
  "guide-neovim": {
    id: "guide-neovim",
    title: "Neovim",
    summary: "Zero-dependency editing: profiles, keymaps, health.",
    sections: [
      {
        id: "profiles",
        heading: "Profiles",
        blocks: [
          {
            kind: "table",
            headers: ["Profile", "Plugins at startup"],
            rows: [
              [
                "minimal",
                "options, keymaps, colorscheme, statusline (SSH/recovery)",
              ],
              [
                "terminal",
                "+ gitsigns, toggleterm, tool launchers, devcontainer CLI",
              ],
              ["development", "same as terminal (default)"],
              ["full", "same as terminal"],
            ],
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Pick a profile",
            code: "DOTTOD_NVIM_PROFILE=minimal nvim",
          },
        ],
      },
      {
        id: "keys",
        heading: "Keymaps",
        blocks: [
          {
            kind: "table",
            headers: ["Keys", "Does"],
            rows: [
              ["<C-h/j/k/l>", "window navigation"],
              ["]b [b", "next/prev buffer"],
              ["<leader>tt/th/tv", "terminal float/horizontal/vertical"],
              ["<leader>gg/dk/kk/bt", "lazygit, lazydocker, k9s, btop"],
              ["<leader>Du/Dc/Dd/De", "devcontainer up/connect/down/exec"],
              ["<leader>e/pe", "toggle explorer"],
            ],
          },
        ],
      },
      {
        id: "health",
        heading: "Health",
        blocks: [
          {
            kind: "p",
            text: ":checkhealth dottod reports the version, profile, lazy.nvim state with the lockfile pin count, external tools, and the devcontainer CLI. The headless battery (scripts/nvim-headless-check.sh) runs the same checks in CI for every profile.",
          },
        ],
      },
    ],
  },
  "guide-ssh": {
    id: "guide-ssh",
    title: "SSH",
    summary: "GitHub host config and key management.",
    sections: [
      {
        id: "merge",
        heading: "Safe merge",
        blocks: [
          {
            kind: "p",
            text: "The ssh task merges the required github.com block (HostName, User git, IdentityFile ~/.ssh/github, IdentitiesOnly, AddKeysToAgent) into your config: missing keys are appended, your values are never modified, unrelated hosts are preserved, and reruns are byte-identical.",
          },
        ],
      },
      {
        id: "keys",
        heading: "Keys",
        blocks: [
          {
            kind: "p",
            text: "An ed25519 pair is generated at ~/.ssh/github (600/644) only when neither half exists. Add the .pub to GitHub once; the task never regenerates it.",
          },
        ],
      },
    ],
  },
  "guide-containers": {
    id: "guide-containers",
    title: "Containers",
    summary: "Podman by default, Docker when selected.",
    sections: [
      {
        id: "select",
        heading: "Selection",
        blocks: [
          {
            kind: "table",
            headers: ["Value", "Meaning"],
            rows: [
              ["podman", "Use Podman (default)"],
              ["docker", "Use Docker (explicit alternative)"],
              ["auto", "Podman if usable, else Docker, else Podman"],
            ],
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Select and inspect",
            code: "_DOT_CONTAINER_RUNTIME=docker ./bin/bootstrap.sh --only container\n./bin/container.sh status",
          },
        ],
      },
      {
        id: "vocabulary",
        heading: "Detection vocabulary",
        blocks: [
          {
            kind: "p",
            text: "Configured (env value) → installed (binary on PATH) → usable (works as you, no sudo) → selected (resolution). Binary-exists is not usable: a stopped daemon or missing user namespaces report exactly that, loudly.",
          },
        ],
      },
    ],
  },
  "guide-fonts": {
    id: "guide-fonts",
    title: "Fonts",
    summary: "User-level Nerd Fonts, no sudo required.",
    sections: [
      {
        id: "install",
        heading: "User-level installs",
        blocks: [
          {
            kind: "p",
            text: "Fonts land in ~/.local/share/fonts (system-wide only with _DOT_NERDFONT_GLOBAL_INSTALL=1). Prerequisites install via apt only when actually missing — a normal rerun touches neither sudo nor the network for present fonts.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Custom set",
            code: "./bin/fonts.sh FiraCode ZedMono",
          },
        ],
      },
      {
        id: "note",
        heading: "Desktop fonts",
        blocks: [
          {
            kind: "callout",
            tone: "info",
            title: "No global overrides",
            text: "dottod never sets GNOME interface fonts. Only the terminal uses these faces.",
          },
        ],
      },
    ],
  },
  commands: {
    id: "commands",
    title: "Commands",
    summary: "Every bootstrap.sh flag, generated from --help.",
    sections: [
      {
        id: "flags",
        heading: "Flags",
        blocks: [
          {
            kind: "table",
            headers: ["Flag", "Does"],
            rows: [
              ["--only <list>", "run only these tasks"],
              ["--skip <list>", "skip these tasks"],
              ["--runtime <name>", "podman, docker or auto (default podman)"],
              ["--parallel", "run tasks concurrently"],
              ["--ui", "include GUI tasks (zed, ghostty)"],
              ["--no-ui", "skip GUI tasks (the default)"],
              ["--yes", "assume yes for prompts"],
              ["--verbose, -v", "stream full task output"],
              ["--list, -l", "list tasks and exit"],
              ["--help, -h", "show help"],
            ],
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Common invocations",
            code: "./bin/bootstrap.sh\n./bin/bootstrap.sh --only shell,tools\n./bin/bootstrap.sh --ui --only zed\n./bin/bootstrap.sh --skip ghostty,zed",
          },
        ],
      },
    ],
  },
  config: {
    id: "config",
    title: "Configuration",
    summary: "Every _DOT_* variable and its default.",
    sections: [
      {
        id: "vars",
        heading: "Variables",
        blocks: [
          {
            kind: "table",
            headers: ["Variable", "Default", "Task"],
            rows: [
              ["_DOT_TARGET_USER", "id -un", "all"],
              ["_DOT_NO_PACKAGES", "0 (1 skips apt; tests)", "all"],
              ["_DOT_CONTAINER_RUNTIME", "podman", "container"],
              ["_DOT_NVIM_MIN_VERSION", "0.11.0", "neovim"],
              ["_DOT_NVIM_VERSION", "v0.12.5", "neovim"],
              ["_DOT_NVIM_ALLOW_TARBALL", "0", "neovim"],
              ["_DOT_NVIM_PROFILE", "development", "neovim"],
              ["_DOT_NERDFONT_VERSION", "v3.4.0", "fonts"],
              ["_DOT_NERDFONT_GLOBAL_INSTALL", "0", "fonts"],
              ["_DOT_RUSTUP_TOOLCHAIN", "stable", "cargo"],
              ["_DOT_RUSTUP_PROFILE", "minimal", "cargo"],
              ["_DOT_BUN_VERSION", "latest", "bun"],
              ["_DOT_ZED_CHANNEL", "stable", "zed"],
              ["_DOT_ZED_VERSION", "latest", "zed"],
              ["GIT_NAME / GIT_EMAIL", "prompt once", "gitconfig"],
              ["_DOT_SSH_DIR", "~/.ssh", "ssh"],
            ],
          },
        ],
      },
    ],
  },
  concepts: {
    id: "concepts",
    title: "Concepts",
    summary:
      "The shared vocabulary: Task, Profile, Healing, runtime states, idempotency.",
    sections: [
      {
        id: "terms",
        heading: "Glossary",
        blocks: [
          {
            kind: "table",
            headers: ["Term", "Means", "Not"],
            rows: [
              [
                "Task",
                "one bin/<id>.sh unit plus its registry entry",
                "script, job",
              ],
              [
                "Profile",
                "DOTTOD_NVIM_PROFILE: minimal, terminal, development, full",
                "mode, tier",
              ],
              [
                "Configured / Selected / Usable",
                "explicit choice vs auto-resolution vs working runtime",
                "—",
              ],
              [
                "Healing",
                "opt-in tarball install when apt is too old",
                "upgrade",
              ],
              [
                "Idempotency",
                "probe before acting; reruns converge without work",
                "—",
              ],
            ],
          },
        ],
      },
    ],
  },
  architecture: {
    id: "architecture",
    title: "Architecture",
    summary: "As-is topology, stack, and the release flow.",
    sections: [
      {
        id: "topology",
        heading: "Topology",
        blocks: [
          {
            kind: "p",
            text: "Single-host workstation provisioner. One interface — bin/bootstrap.sh — drives twelve task scripts against $HOME, /etc/apt and ~/.config, escalating once per run via sudo or doas. No servers, no databases; state lives in symlinks, backups (*.dottod.bak), caches and lockfiles.",
          },
          {
            kind: "code",
            lang: "text",
            caption: "Layers",
            code: "./bin/bootstrap.sh --only/--skip/--parallel/--ui\n        └─► bin/<task>.sh ─► $HOME, /etc/apt, ~/.config\n                    (via _priv sudo/doas, cached per run)",
          },
        ],
      },
      {
        id: "stack",
        heading: "Stack",
        blocks: [
          {
            kind: "table",
            headers: ["Layer", "Technology"],
            rows: [
              [
                "Orchestration",
                "bash (set -Eeuo pipefail), shared bin/utils.sh",
              ],
              ["Shell", "plain bash, no frameworks"],
              [
                "Editors",
                "vim + vim-plug; Neovim ≥ 0.11 + lazy.nvim (16 pins)",
              ],
              ["Tests", "BATS suites + release-logic tests"],
              [
                "CI",
                "GitHub workflows: shell, container, neovim, docs, release",
              ],
              [
                "Releases",
                "Conventional Commits → CHANGELOG → tag → GitHub Release",
              ],
            ],
          },
        ],
      },
      {
        id: "history",
        heading: "History",
        blocks: [
          {
            kind: "p",
            text: "The zsh/oh-my-zsh/spaceship stack, the desktop and vscode tasks, and the Ratatui TUI were removed in the terminal-first revision. The full archaeology lives in the repository (docs/product/introspec.md, retrofit.md) — repo-only, not published here.",
          },
        ],
      },
    ],
  },
  roadmap: {
    id: "roadmap",
    title: "Roadmap",
    summary: "What is specified but not built.",
    maturity: "planned",
    sections: [
      {
        id: "planned",
        heading: "Planned",
        maturity: "planned",
        blocks: [
          {
            kind: "p",
            text: "These items exist as specifications, not code. They are tracked here so the status is honest — nothing below is presented as working.",
          },
          {
            kind: "ul",
            items: [
              "Per-task status actions (uniform verify surface for vim, gitconfig, ssh, tools, fonts, shell).",
              "vhs terminal demos for the command reference.",
              "Portuguese (pt-BR) translation of the remaining guides.",
            ],
          },
        ],
      },
      {
        id: "decisions",
        heading: "Deliberately not planned",
        blocks: [
          {
            kind: "ul",
            items: [
              "LSP, Treesitter, formatters and linters in the Neovim config (removed by design).",
              "A dottod one-liner installer (a flagship curl|sh entry point contradicts the download-then-run posture).",
              "Multi-user or team stories (single-user scope, confirmed).",
            ],
          },
        ],
      },
    ],
  },
};

export const enUS: DocsContent = {
  ui: {
    siteName: "dottod",
    siteTagline: "Debian workstation, rebuilt by one plain-bash command.",
    skipToContent: "Skip to content",
    menu: "Menu",
    close: "Close",
    search: "Search",
    searchPlaceholder: "Search pages…",
    searchNoResults: "No pages match “{query}”.",
    searchSuggestions: "Try “bootstrap”, “neovim”, or “--ui”.",
    language: "Language",
    theme: "Theme",
    themeDark: "Switch to dark theme",
    themeLight: "Switch to light theme",
    breadcrumbHome: "dottod",
    onThisPage: "On this page",
    version: "Version",
    copy: "Copy",
    copied: "Copied",
    footerNote:
      "dottod docs — truth-first from the repository. Re-run the bootstrap any time.",
    nextPage: "Next",
    maturityLabels: {
      implemented: "Implemented",
      partial: "Partially implemented",
      planned: "Planned",
      unavailable: "Unavailable",
      upstream: "Upstream limitation",
      na: "N/A",
    },
    groupLabels: {
      start: "Start",
      tasks: "Tasks",
      guides: "Guides",
      reference: "Reference",
      project: "Project",
    },
    notFoundTitle: "That page doesn't exist",
    notFoundText: "The pages are listed on the left.",
    backHome: "Back to Overview",
  },
  pages,
};
