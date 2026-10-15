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
      subtitle: "Rebuild a Linux workstation with one plain-bash command.",
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
            text: "dottod is a personal dotfiles and workstation bootstrap for Debian/Ubuntu, Gentoo, Arch, Fedora and Alpine. One entry point — bin/bootstrap.sh — runs eleven idempotent tasks: shell, fonts, editors, container runtime, terminal, CLI tooling, and GitHub SSH. Every task checks before it acts, backs up what it replaces, and reports PASS or FAIL with a per-task log.",
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
              ["container", "Rootless Podman"],
              ["zed", "Zed editor (GUI, opt-in)"],
              ["gitconfig", "Git identity"],
              ["ssh", "GitHub host merge + ed25519 key"],
              [
                "tools",
                "btop, bat, xclip, jq, fzf, shellcheck, bats, shfmt, just; opt-in extras: gh, httpie, chafa",
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
            text: "You need Debian/Ubuntu, Gentoo, Arch, Fedora or Alpine (with bash installed — on Alpine, apk add bash first), plus sudo or doas. dottod detects the distribution and uses its package manager; anything else is refused before any install. If sudo is not passwordless you will be asked once; otherwise run as root. GUI tasks (zed) are skipped by default — pass --ui to include them.",
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
              "Reinstall your distribution and clone this repository.",
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
      "The eleven bootstrap tasks: what each does and whether it is safe to re-run.",
    sections: [
      {
        id: "all",
        heading: "All tasks",
        blocks: [
          {
            kind: "table",
            headers: ["Task", "Safe to re-run", "Needs"],
            rows: [
              ["shell", "Yes", "packages (git, bash)"],
              ["fonts", "Yes", "nothing when present"],
              ["vim", "Yes", "network for missing plugins only"],
              ["neovim", "Yes", "package or tarball (0.11+)"],
              ["container", "Yes", "packages on first run"],
              ["zed", "Yes (opt-in)", "network"],
              ["gitconfig", "Yes", "GIT_NAME/GIT_EMAIL once"],
              ["ssh", "Yes", "nothing (keygen once)"],
              ["tools", "Yes", "packages"],
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
            text: "Installs Neovim (the distro package when its candidate is ≥ 0.11, otherwise fails with instructions), links ~/.config/nvim to the repo (existing configs are backed up, never deleted), and lets lazy.nvim sync 16 pinned plugins on first launch. Profiles via DOTTOD_NVIM_PROFILE: minimal, terminal, development (default), full.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Heal via tarball when the package is too old (glibc)",
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
                "0.10.4 from the distro packages is below the minimum",
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
    summary: "Rootless Podman. Safe to re-run.",
    sections: [
      {
        id: "what",
        heading: "What it does",
        blocks: [
          {
            kind: "p",
            text: "Ensures rootless Podman (uidmap + subuid/subgid ranges) and validates it with podman info as you, no sudo. container.sh status prints the installation/rootless report without changing anything.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Select and inspect",
            code: "./bin/bootstrap.sh --only container\n./bin/container.sh status",
          },
          {
            kind: "demo",
            gif: "status-commands.gif",
            alt: "Terminal recording: container.sh status and cargo.sh status reports.",
            transcript:
              "➜ ./bin/container.sh status\n\nContainer runtime\n-----------------\nPodman:     installed 5.4.2\nRootless:   yes\n\n➜ ./bin/cargo.sh status\n\nRust toolchain\n--------------\nCargo:    cargo 1.98.0 (797e8a9bc 2026-08-05)\nHome:     /home/lucas/.cargo\nProfile:  minimal (default for fresh installs)\nToolchain: stable (default for fresh installs)\nRustup:   present",
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
            text: "Yes. A usable engine is a no-op with zero privilege calls; subuid ranges are allocated once. Never migrates or destroys other container engines.",
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
            text: "Sets user.name and user.email from GIT_NAME/GIT_EMAIL, the existing global config, or one TTY prompt — then writes ~/.gitconfig (backed up first). A distinct work identity for repositories under ~/codes/ is written to ~/.gitconfig-work and wired in via [includeIf]; it falls back to personal when GIT_WORK_NAME/GIT_WORK_EMAIL are unset. Matching values are left untouched: no backup, no rewrite.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Non-interactive",
            code: 'GIT_NAME="Your Name" GIT_EMAIL="you@example.com" \\\nGIT_WORK_NAME="You At Work" GIT_WORK_EMAIL="you@work.example.com" \\\n  ./bin/gitconfig.sh',
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
            text: "Installs btop, xclip, bat, jq, curl, tar, ca-certificates, lsof, fzf, shellcheck, bats, shfmt and just from the distro's packages (skipped when all present), and links bat/batcat and fd/fdfind so both spellings work. Extras are opt-in via --extras or DOT_TOOLS_EXTRA (all off by default): httpie, chafa and gh from the distro's packages — gh from its official apt repository (signed keyring) on Debian/Ubuntu.",
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
            text: "Yes. Every tool probes PATH before installing; the package manager is skipped wholesale when everything is present.",
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
            text: "Installs the single bun binary from the official release zip (sha256-verified against the release's SHASUMS256.txt; the musl build on Alpine) into ~/.local/bin — never bun's installer script, which would append to ~/.bashrc. Then installs the devcontainer CLI with bun install --global and runs it with Bun through a ~/.local/bin/devcontainer wrapper: no Node.js needed.",
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
            text: "Three styles in styles/ share one collector library (promptlib.sh: git state, project directory, language markers, disk and duration). robbyrussell is the default: an exit-aware arrow (green on success, red on failure), the current directory, and git branch with a dirty marker — per-repo opt-out with git config dottod.hide-dirty 1. Switch with DOT_PROMPT_STYLE=kali or powerline. No plugins, no frameworks; PROMPT_COMMAND does the work.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Switch styles",
            code: "DOT_PROMPT_STYLE=kali      # two-line kali terminal\nDOT_PROMPT_STYLE=powerline  # segmented blocks (needs a Nerd Font)",
          },
          {
            kind: "code",
            lang: "text",
            caption: "robbyrussell (default)",
            code: "➜  dottod git:(feat/prompt-styles) ✗",
          },
          {
            kind: "code",
            lang: "text",
            caption: "kali — red # as root, red $ on failure",
            code: "┌──(user㉿host)-[dottod]\n└─$",
          },
          {
            kind: "code",
            lang: "text",
            caption: "powerline — shown with DOT_PROMPT_GLYPHS=ascii",
            code: " user > dottod > feat/prompt-styles ✗    3s ✓ < 09:35 < 27G",
          },
          {
            kind: "callout",
            tone: "info",
            title: "Nerd Font",
            text: "The powerline separators render as angled blocks only with a Nerd Font installed; without one, set DOT_PROMPT_GLYPHS=ascii as above. The robbyrussell and kali styles work in any terminal.",
          },
        ],
      },
      {
        id: "path",
        heading: "PATH layout",
        blocks: [
          {
            kind: "p",
            text: "~/.local/bin first, then ~/.bun/bin and ~/.cargo/bin when they exist. Prepended once per shell — re-sourcing never duplicates entries.",
          },
        ],
      },
      {
        id: "utils",
        heading: "Utilities",
        blocks: [
          {
            kind: "p",
            text: "scripts/.*.sh libraries load aliases (lll, git shortcuts, clip, pclip, cclip), functions (mkcd, extract, ff, gr, psg, port, serve, gcl) and the ctr container dispatcher. Only the hidden library files load — scripts/*.sh are programs and are never sourced.",
          },
        ],
      },
      {
        id: "projects",
        heading: "Projects",
        blocks: [
          {
            kind: "p",
            text: "The codes switcher jumps between git projects under CODES_ROOTS (default ~/codes:~/code:~/projects:~/src:~/dev:~/work), newest activity first with a git status column. Type codes for the fzf picker, codes <name> to jump with typo-tolerant matching, codes -l to list, codes -p for scripts.",
          },
          {
            kind: "p",
            text: "Sibling repos under one directory show as parent/name, and submodule checkouts nest under their superproject — every row is still a real path. Query by parent (codes coparticipacao) or qualified name (codes coparticipacao/front). CODES_GROUP=0 restores the flat list, CODES_SUBMODULES=0 drops nested checkouts like before.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Jump between projects",
            code: "codes                     # pick from everything\ncodes front               # ambiguous names open the picker\ncodes coparticipacao/back # qualified jump",
          },
        ],
      },
      {
        id: "updates",
        heading: "Updates",
        blocks: [
          {
            kind: "p",
            text: "Interactive shells check for newer dottod releases weekly: the check runs detached and never blocks startup, and a known update prints one notice with both versions. dottod-update fast-forwards a git checkout (tarball installs get re-download instructions instead). DOT_UPDATE_DAYS tunes the interval, DOT_NO_UPDATE_CHECK=1 disables it.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Update dottod",
            code: "dottod-update",
          },
        ],
      },
      {
        id: "profiles",
        heading: "Claude profiles",
        blocks: [
          {
            kind: "p",
            text: "The shell offers named Claude Code profiles (work, personal, …) over one shared store: memory, skills, plugins and projects live in ~/.claude, while each ~/.claude-<name> overlay keeps its own login, settings and identity dirs. claude picks a profile (fzf), claude -P selects one for the run, claude-profile manages overlays. The picker side panel shows each profile's account, plan and 5h/7d usage with reset times. First run builds the overlay; a fresh profile asks for /login. Always launch through the wrapper — a bare claude /login writes outside the profiles.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Launch with a profile",
            code: "claude              # pick from all profiles\nclaude -P work      # one profile for this run\nclaude-profile add extra  # new overlay",
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
              ["<leader>bt", "btop"],
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
  "guide-distributions": {
    id: "guide-distributions",
    title: "Distributions",
    summary:
      "Debian/Ubuntu, Gentoo, Arch, Fedora and Alpine — and what is verified where.",
    sections: [
      {
        id: "how",
        heading: "How it works",
        blocks: [
          {
            kind: "p",
            text: "Every task installs packages through one layer (lib/package.sh): it reads /etc/os-release, picks the distribution's own package manager and its real package names. Any other distribution is refused before a single package command runs.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "What dottod detected here",
            code: "dottod-doctor | grep distro",
          },
        ],
      },
      {
        id: "verified",
        heading: "What has been verified",
        blocks: [
          {
            kind: "p",
            text: "Only what was actually run is claimed. Containers are throwaway pinned images, each task run twice; Ubuntu 24.04 was checked for package names only.",
          },
          {
            kind: "table",
            headers: [
              "",
              "Debian 13",
              "Gentoo",
              "Arch",
              "Fedora 42",
              "Alpine 3.22",
            ],
            rows: [
              [
                "shell, vim, gitconfig, ssh, fonts",
                "✅",
                "✅",
                "✅",
                "✅",
                "✅",
              ],
              [
                "neovim ≥ 0.11",
                "✅ tarball (package is 0.10.4)",
                "✅ 0.11.7",
                "✅ 0.12.6",
                "✅ 0.11.5",
                "✅ 0.11.1",
              ],
              ["cargo (rustup)", "✅", "✅", "✅", "✅", "✅ musl"],
              [
                "bun",
                "✅ verified",
                "✅",
                "✅ verified",
                "✅ verified",
                "✅ musl, verified",
              ],
              [
                "tools + gh",
                "✅ gh via GitHub's apt repo",
                "names only",
                "✅",
                "✅",
                "✅",
              ],
              [
                "rootless Podman",
                "✅ host",
                "pending (real laptop)",
                "—",
                "rootful only",
                "helpers + subids only",
              ],
              [
                "zed (--ui)",
                "not run",
                "not run",
                "not run",
                "not run",
                "unsupported (glibc only)",
              ],
            ],
          },
        ],
      },
      {
        id: "notes",
        heading: "Per distribution",
        blocks: [
          {
            kind: "ul",
            items: [
              "Debian/Ubuntu: apt-get, index refreshed once per run; batcat and fdfind also get the plain bat and fd names.",
              'Gentoo: emerge with your profile, USE flags and EMERGE_DEFAULT_OPTS untouched; dottod never syncs and never writes /etc/portage. Packages may build from source; on OpenRC, rootless Podman needs rc_cgroup_mode="unified" (container status reports it).',
              "Arch: pacman -S --needed, never a lone -Sy (partial upgrades); if a package is not found, run pacman -Syu first. No AUR.",
              "Fedora: dnf install -y.",
              "Alpine: install bash first. Bun and rustup use musl builds; Neovim comes from apk; Zed is skipped with a reason; no chsh, so the shell task prints the usermod command.",
            ],
          },
        ],
      },
      {
        id: "check",
        heading: "Check it yourself",
        blocks: [
          {
            kind: "code",
            lang: "bash",
            caption:
              "Package names, then the core bootstrap twice (Podman, capped at 3 GiB / 2 CPUs)",
            code: "DOTTOD_TEST_INTEGRATION=1 tests/integration/pkg-resolve.sh gentoo arch\nDOTTOD_TEST_INTEGRATION=1 tests/integration/core-smoke.sh alpine",
          },
        ],
      },
    ],
  },
  "guide-containers": {
    id: "guide-containers",
    title: "Containers",
    summary: "Rootless Podman only.",
    sections: [
      {
        id: "select",
        heading: "Setup",
        blocks: [
          {
            kind: "code",
            lang: "bash",
            caption: "Install and inspect",
            code: "./bin/bootstrap.sh --only container\n./bin/container.sh status",
          },
        ],
      },
      {
        id: "vocabulary",
        heading: "Detection vocabulary",
        blocks: [
          {
            kind: "p",
            text: "Installed (binary on PATH) → usable (rootless podman info works as you, no sudo). Binary-exists is not usable: missing user namespaces or subuid ranges report exactly that, loudly.",
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
            text: "Fonts land in ~/.local/share/fonts (system-wide only with _DOT_NERDFONT_GLOBAL_INSTALL=1). Prerequisites install from the distro packages only when actually missing — a normal rerun touches neither sudo nor the network for present fonts.",
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
              [
                "--extras <list>",
                "opt-in tools for the tools task (gh, httpie, chafa, or all)",
              ],
              ["--parallel", "run tasks concurrently"],
              ["--ui", "include GUI tasks (zed)"],
              ["--no-ui", "skip GUI tasks (the default)"],
              ["--yes", "assume yes for prompts"],
              ["--verbose, -v", "stream full task output"],
              [
                "--status",
                "print every selected task's status report (changes nothing)",
              ],
              ["--list, -l", "list tasks and exit"],
              ["--help, -h", "show help"],
            ],
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Common invocations",
            code: "./bin/bootstrap.sh\n./bin/bootstrap.sh --only shell,tools\n./bin/bootstrap.sh --ui --only zed\n./bin/bootstrap.sh --only tools --extras gh,httpie",
          },
        ],
      },
      {
        id: "status",
        heading: "Status reports",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Every task answers status with a read-only report: what is installed, linked or configured, and nothing is installed, written or asked. bootstrap.sh --status prints every report and honours --only, --skip and --ui; a single task runs as <task>.sh status (fonts.sh status takes font names too).",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Status reports",
            code: "./bin/bootstrap.sh --status\n./bin/bootstrap.sh --status --only ssh,gitconfig\n./bin/ssh.sh status\n./bin/fonts.sh status FiraCode",
          },
          {
            kind: "demo",
            gif: "status-report.gif",
            alt: "Terminal recording: bootstrap.sh --status printing the shell, vim and tools reports.",
            transcript:
              "➜ ./bin/bootstrap.sh --status --only shell,vim,tools\n\nShell\n-----\nBash:      GNU bash, version 5.2.37(1)-release (x86_64-pc-linux-gnu)\nLogin:     /bin/bash (bash)\nBashrc:    /home/demo/.bashrc (symlink -> /vhs/config/.custom.bashrc (dottod))\n\nVim\n---\nInstalled: VIM - Vi IMproved 9.1 (2024 Jan 02, compiled May 23 2025 00:48:59)\nVimrc:     /home/demo/.vimrc (missing)\nvim-plug:  missing\nPlugins:   0/0 installed\n\nTools\n-----\nCore:      8/12 present (missing: xclip bats shfmt just)\nExtras:    0/3 present (missing: gh httpie chafa)\nSelected:  none (DOT_TOOLS_EXTRA)",
          },
        ],
      },
      {
        id: "demo",
        heading: "Demo",
        blocks: [
          {
            kind: "demo",
            gif: "bootstrap-help.gif",
            alt: "Terminal recording: bootstrap.sh --help output, then the task list.",
            transcript:
              "➜ ./bin/bootstrap.sh --help\n\nUsage: bootstrap.sh [options]\n\nBootstraps the workstation by running the dottod task scripts.\n\nOptions:\n  --only <list>      Comma-separated list of tasks to run (default: all)\n  --skip <list>      Comma-separated list of tasks to skip\n  --parallel         Run tasks concurrently instead of sequentially\n  --extras <list>    Opt-in tools for the tools task (gh, httpie, chafa, or\n                     all); default none\n  --ui               Include GUI tasks (zed); default skips them\n  --no-ui            Skip GUI tasks (the default; explicit form of omitting --ui)\n  --yes              Assume yes for prompts\n  --verbose, -v      Stream full task output (default: summarized)\n  --status           Print every selected task's status report (changes\n                     nothing; honours --only, --skip and --ui)\n  --list, -l         List available tasks and exit\n  --help, -h         Show this help\n\n➜ ./bin/bootstrap.sh --list\n\nshell fonts vim neovim container zed gitconfig ssh tools cargo bun",
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
              [
                "_DOT_NO_PACKAGES",
                "0 (1 skips package installs; tests)",
                "all",
              ],
              ["DOT_TOOLS_EXTRA", "none (comma list or all)", "tools"],
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
                "Healing",
                "opt-in tarball install when the package is too old",
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
            text: "Single-host workstation provisioner. One interface — bin/bootstrap.sh — drives eleven task scripts against $HOME, the distro package manager and ~/.config, escalating once per run via sudo or doas. No servers, no databases; state lives in symlinks, backups (*.dottod.bak), caches and lockfiles.",
          },
          {
            kind: "code",
            lang: "text",
            caption: "Layers",
            code: "./bin/bootstrap.sh --only/--skip/--parallel/--ui\n        └─► bin/<task>.sh ─► $HOME, package manager, ~/.config\n                    (via _priv sudo/doas, cached per run)",
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
    summary: "What shipped in 2.0.0, and how new work gets on the list.",
    sections: [
      {
        id: "delivered",
        heading: "Delivered in 2.0.0",
        maturity: "implemented",
        blocks: [
          {
            kind: "ul",
            items: [
              "Per-task status actions: every task answers <task>.sh status with a read-only report, and bootstrap.sh --status prints them all (see Commands).",
              "vhs terminal demos for the command reference: bootstrap.sh --help and bootstrap.sh --status, re-rendered by docs CI on every change.",
              "Portuguese (pt-BR) translation of every guide.",
            ],
          },
        ],
      },
      {
        id: "planned",
        heading: "Planned",
        blocks: [
          {
            kind: "p",
            text: "Nothing is planned right now. New work starts as a specification under specs/ and is listed here, labelled Planned, until it is built.",
          },
        ],
      },
    ],
  },
};

export const enUS: DocsContent = {
  ui: {
    siteName: "dottod",
    siteTagline: "Linux workstation, rebuilt by one plain-bash command.",
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
