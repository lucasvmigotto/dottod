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
    title: "Visão geral",
    summary: "O que é o dottod, por que bash puro, e as tarefas de relance.",
    hero: {
      eyebrow: "dottod",
      title: "dottod",
      subtitle: "Reconstrua uma estação Linux com um comando bash puro.",
      ctaLabel: "Começar",
      ctaHref: "/start",
      transcript: TRANSCRIPT,
    },
    sections: [
      {
        id: "what",
        heading: "O que é",
        blocks: [
          {
            kind: "p",
            text: "dottod são dotfiles pessoais e bootstrap de estação para Debian/Ubuntu, Gentoo, Arch, Fedora e Alpine. Um ponto de entrada — bin/bootstrap.sh — executa onze tarefas idempotentes: shell, fontes, editores, runtime de contêineres, terminal, ferramentas CLI e SSH do GitHub. Cada tarefa verifica antes de agir, faz backup do que substitui e relata PASS ou FAIL com um log por tarefa.",
          },
        ],
      },
      {
        id: "why-bash",
        heading: "Bash puro, de propósito",
        blocks: [
          {
            kind: "p",
            text: "Sem plugins, sem frameworks, sem pilha de prompt. zsh, oh-my-zsh e spaceship foram removidos depois de travar terminais interativos; o substituto é um bashrc com prompt sensível a erro, contexto git e pequenos utilitários. Um ponto de entrada, um log por tarefa, e cada tarefa segura para rodar duas vezes.",
          },
        ],
      },
      {
        id: "tasks-glance",
        heading: "Tarefas de relance",
        blocks: [
          {
            kind: "table",
            headers: ["Tarefa", "Faz"],
            rows: [
              ["shell", "bash como shell de login, liga ~/.bashrc"],
              ["fonts", "Nerd Fonts, nível de usuário"],
              ["vim", "vim + vim-plug + plugins"],
              ["neovim", "Neovim ≥ 0.11, lazy.nvim, 16 plugins fixos"],
              ["container", "Podman rootless"],
              ["zed", "editor Zed (GUI, opt-in)"],
              ["gitconfig", "identidade Git"],
              ["ssh", "merge do host GitHub + chave ed25519"],
              [
                "tools",
                "btop, bat, xclip, jq, fzf, shellcheck, bats, shfmt, just; extras opt-in: gh, httpie, chafa, fastfetch",
              ],
              ["cargo", "toolchain Rust via rustup"],
              ["bun", "runtime Bun + CLI devcontainer"],
              ["secrets", "pass + logins de registries (opt-in)"],
            ],
          },
        ],
      },
    ],
  },
  start: {
    id: "start",
    title: "Começando",
    summary: "Clone, execute, verifique — e recupere após um reset.",
    sections: [
      {
        id: "install",
        heading: "Instalar e executar",
        blocks: [
          {
            kind: "code",
            lang: "bash",
            caption: "Clone e bootstrap",
            code: "git clone https://github.com/lucasvmigotto/dottod.git\ncd dottod\n./bin/bootstrap.sh",
          },
          {
            kind: "p",
            text: "Você precisa de Debian/Ubuntu, Gentoo, Arch, Fedora ou Alpine (com bash instalado — no Alpine, apk add bash antes), mais sudo ou doas. O dottod detecta a distribuição e usa o gerenciador de pacotes dela; qualquer outra é recusada antes de instalar algo. Se o sudo não for passwordless, a senha é pedida uma vez; senão rode como root. Tarefas GUI (zed) são puladas por padrão — passe --ui para incluí-las.",
          },
        ],
      },
      {
        id: "verify",
        heading: "Verificar",
        blocks: [
          {
            kind: "p",
            text: "O bootstrap termina com um resumo PASS/FAIL. Cada tarefa também escreve /tmp/dottod/<tarefa>.log no modo silencioso (--verbose mostra tudo). Rode de novo quando quiser: cada tarefa verifica antes de agir.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Rode de novo com segurança",
            code: "./bin/bootstrap.sh",
          },
        ],
      },
      {
        id: "recover",
        heading: "Recuperar após um reset",
        blocks: [
          {
            kind: "ol",
            items: [
              "Reinstale sua distribuição e clone este repositório.",
              "Rode ./bin/bootstrap.sh (passe GIT_NAME/GIT_EMAIL para um gitconfig não interativo).",
              "Para uma tarefa que falhou: ./bin/bootstrap.sh --only <tarefa>, depois leia /tmp/dottod/<tarefa>.log.",
              "Neovim abaixo de 0.11: rode de novo com _DOT_NVIM_ALLOW_TARBALL=1 para curar via tarball.",
            ],
          },
        ],
      },
    ],
  },
  tasks: {
    id: "tasks",
    title: "Tarefas",
    summary: "As onze tarefas: o que cada uma faz e se é seguro repetir.",
    sections: [
      {
        id: "all",
        heading: "Todas as tarefas",
        blocks: [
          {
            kind: "table",
            headers: ["Tarefa", "Seguro repetir", "Precisa"],
            rows: [
              ["shell", "Sim", "pacotes (git, bash)"],
              ["fonts", "Sim", "nada quando presentes"],
              ["vim", "Sim", "rede só para plugins faltantes"],
              ["neovim", "Sim", "pacote ou tarball (0.11+)"],
              ["container", "Sim", "pacotes na primeira vez"],
              ["zed", "Sim (opt-in)", "rede"],
              ["gitconfig", "Sim", "GIT_NAME/GIT_EMAIL uma vez"],
              ["ssh", "Sim", "nada (chave uma vez)"],
              ["tools", "Sim", "pacotes"],
              ["cargo", "Sim", "rede uma vez"],
              ["bun", "Sim", "rede uma vez"],
              ["secrets", "Sim (opt-in)", "pacotes uma vez"],
            ],
          },
          {
            kind: "p",
            text: "Abra uma tarefa abaixo para flags, ambiente e solução de problemas. Tarefas GUI nunca rodam sem --ui.",
          },
        ],
      },
    ],
  },
  "task-shell": {
    id: "task-shell",
    title: "shell",
    summary: "bash como login shell; liga ~/.bashrc. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Garante o bash instalado e como shell de login (chsh, pulado quando já é bash), depois liga config/.custom.bashrc em ~/.bashrc com backup. O bashrc traz prompt sensível a erro, segmento git, entradas de PATH e utilitários (mkcd, extract, ff, gr, gcl) mais o despachante ctr.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Rodar sozinha",
            code: "./bin/bootstrap.sh --only shell",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotente?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Sim. chsh é pulado quando o bash já é o shell; um link correto é no-op sem backups extras.",
          },
        ],
      },
    ],
  },
  "task-fonts": {
    id: "task-fonts",
    title: "fonts",
    summary: "Nerd Fonts, nível de usuário. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Instala FiraCode, FiraMono, RobotoMono, NerdFontsSymbolsOnly e ZedMono em ~/.local/share/fonts (troque com nomes na linha de comando ou _DOT_NERDFONT_VERSION). Fontes instaladas são detectadas com fc-list e puladas — nada baixa de novo.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Rodar sozinha",
            code: "./bin/bootstrap.sh --only fonts\n./bin/fonts.sh FiraCode ZedMono",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotente?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Sim, e sem sudo quando curl, fontconfig e unzip existem: pacotes só instalam para dependências realmente faltantes. Fontes nunca tocam configurações do GNOME — só o terminal as usa.",
          },
          {
            kind: "table",
            headers: ["Variável", "Padrão"],
            rows: [
              ["_DOT_NERDFONT_VERSION", "v3.4.0"],
              ["_DOT_NERDFONT_GLOBAL_INSTALL", "0 (nível de usuário)"],
            ],
          },
        ],
      },
    ],
  },
  "task-vim": {
    id: "task-vim",
    title: "vim",
    summary: "vim + vim-plug + plugins. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Instala vim, baixa vim-plug (com retries), liga ~/.vimrc, depois roda PlugInstall só para plugins faltantes em ~/.vim/plugged. Coexiste com Neovim; nunca é substituído por ele.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Rodar sozinho",
            code: "./bin/bootstrap.sh --only vim",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotente?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Sim. vim-plug e plugins presentes são pulados; um link correto é no-op.",
          },
        ],
      },
    ],
  },
  "task-neovim": {
    id: "task-neovim",
    title: "neovim",
    summary: "Neovim ≥ 0.11 com config lazy.nvim enxuta. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Instala Neovim (o pacote da distro quando o candidato é ≥ 0.11, senão falha com instruções), liga ~/.config/nvim ao repositório (configs existentes viram backup, nunca deletadas), e deixa o lazy.nvim sincronizar 16 plugins fixos na primeira abertura. Perfis via DOTTOD_NVIM_PROFILE: minimal, terminal, development (padrão), full.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Curar via tarball quando o pacote é velho (glibc)",
            code: "_DOT_NVIM_ALLOW_TARBALL=1 ./bin/neovim.sh",
          },
        ],
      },
      {
        id: "troubleshoot",
        heading: "Solução de problemas",
        blocks: [
          {
            kind: "table",
            headers: ["Sintoma", "Correção"],
            rows: [
              [
                "0.10.4 dos pacotes da distro abaixo do mínimo",
                "Rode de novo com _DOT_NVIM_ALLOW_TARBALL=1",
              ],
              [
                "Tarball não produziu nvim",
                "Verifique se ~/.local/bin está no PATH",
              ],
              [
                "Um nvim velho sombreia o novo",
                "A cura liga ~/.local/bin primeiro; abra um shell de login",
              ],
            ],
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotente?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Sim. Binário compatível pula; link correto é no-op sem backups extras. :checkhealth dottod relata perfil e ferramentas.",
          },
        ],
      },
    ],
  },
  "task-container": {
    id: "task-container",
    title: "container",
    summary: "Podman rootless. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Garante Podman rootless (uidmap + faixas subuid/subgid) e valida com podman info como você, sem sudo. container.sh status mostra instalação/rootless sem mudar nada.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Escolher e inspecionar",
            code: "./bin/bootstrap.sh --only container\n./bin/container.sh status",
          },
          {
            kind: "demo",
            gif: "status-commands.gif",
            alt: "Gravação de terminal: relatórios de container.sh status e cargo.sh status.",
            transcript:
              "➜ ./bin/container.sh status\n\nContainer runtime\n-----------------\nPodman:     installed 5.4.2\nRootless:   yes\n\n➜ ./bin/cargo.sh status\n\nRust toolchain\n--------------\nCargo:    cargo 1.98.0 (797e8a9bc 2026-08-05)\nHome:     /home/lucas/.cargo\nProfile:  minimal (default for fresh installs)\nToolchain: stable (default for fresh installs)\nRustup:   present",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotente?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Sim. Engine usável é no-op sem chamadas privilegiadas; faixas subuid alocadas uma vez. Nunca migra nem destrói o outro runtime.",
          },
        ],
      },
    ],
  },
  "task-zed": {
    id: "task-zed",
    title: "zed",
    summary: "Editor Zed, nível de usuário. Opt-in com --ui. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Baixa o instalador oficial e roda de um arquivo (nunca pipe-to-shell) em ~/.local/bin. Canal e versão passam como o instalador espera.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Rodar sozinho",
            code: "./bin/bootstrap.sh --ui --only zed",
          },
        ],
      },
      {
        id: "env",
        heading: "Ambiente",
        blocks: [
          {
            kind: "table",
            headers: ["Variável", "Padrão"],
            rows: [
              ["_DOT_ZED_CHANNEL", "stable"],
              ["_DOT_ZED_VERSION", "latest"],
            ],
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotente?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Sim. zed presente pula sem rede. Pulado sem --ui.",
          },
        ],
      },
    ],
  },
  "task-gitconfig": {
    id: "task-gitconfig",
    title: "gitconfig",
    summary: "Identidade Git. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Define user.name e user.email a partir de GIT_NAME/GIT_EMAIL, da config global existente, ou de um prompt no TTY — depois escreve ~/.gitconfig (com backup). GIT_GLOBAL_IDENTITY=0 escreve o resto do ~/.gitconfig sem identidade global, para máquinas onde cada repositório define a sua. Com GIT_WORK_NAME/GIT_WORK_EMAIL, a identidade de trabalho fica em ~/.gitconfig-work para o gwork. Valores iguais são deixados intactos: sem backup, sem reescrita.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Não interativo",
            code: 'GIT_NAME="Seu Nome" GIT_EMAIL="voce@exemplo.com" \\\nGIT_WORK_NAME="Seu Nome no Trabalho" GIT_WORK_EMAIL="voce@trabalho.exemplo.com" \\\n  ./bin/gitconfig.sh\n\n# sem identidade global (cada repo define a sua)\nGIT_GLOBAL_IDENTITY=0 ./bin/gitconfig.sh',
          },
        ],
      },
      {
        id: "work",
        heading: "Repositórios de trabalho (gwork)",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "A identidade de trabalho é só um dado: sem includeIf, então um repositório é pessoal até você dizer o contrário — na config local dele, onde quer que esteja. gwork clone passa a URL intacta para o git clone: SSH ou HTTPS, Azure DevOps, Bitbucket, GitLab, GitHub ou seu próprio host, e o clone cai onde o git clone o colocaria. Um clone que falha não configura nada. GIT_WORK_NAME/GIT_WORK_EMAIL no ambiente têm precedência sobre ~/.gitconfig-work.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "gwork",
            code: "gwork clone git@ssh.dev.azure.com:v3/org/project/repo  # clona como trabalho e entra\ngwork clone https://gitlab.com/group/sub/repo.git api --depth 1\ngwork set [dir]     # marca um checkout existente como trabalho\ngwork unset [dir]   # volta à identidade global\ngwork               # qual identidade este repo resolve\ncodes --work        # só repositórios de trabalho",
          },
          {
            kind: "p",
            text: "O codes mostra o contexto de cada repositório — trabalho quando o email que o git resolve ali é o de trabalho, pessoal caso contrário — e filtra por ele com --work, --personal e --by-context.",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotente?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Sim. Valores idênticos pulam em silêncio; valores mudados viram backup e reescrita, depois verificados por leitura.",
          },
        ],
      },
    ],
  },
  "task-ssh": {
    id: "task-ssh",
    title: "ssh",
    summary: "Merge do host GitHub + chave ed25519. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Mescla as opções github.com obrigatórias de config/.ssh.config em ~/.ssh/config (só chaves faltantes; seus valores nunca são sobrescritos; reruns byte-idênticos), depois gera uma chave ed25519 em ~/.ssh/github quando nenhuma metade existe — nunca regenera.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Rodar sozinho",
            code: "./bin/bootstrap.sh --only ssh",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotente?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Sim. Configs completas e chaves existentes são intocadas; exatamente uma estrofe Host github.com, validada com ssh -G.",
          },
        ],
      },
    ],
  },
  "task-tools": {
    id: "task-tools",
    title: "tools",
    summary: "Caixa de ferramentas + GitHub CLI. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Instala btop, xclip, bat, jq, curl, tar, ca-certificates, lsof, fzf, shellcheck, bats, shfmt e just dos pacotes da distro (pulado quando tudo presente), e liga bat/batcat e fd/fdfind para os dois nomes funcionarem. Extras são opt-in via --extras ou DOT_TOOLS_EXTRA (todos desligados por padrão): httpie, chafa, fastfetch e gh dos pacotes da distro — gh do repositório apt oficial (keyring assinado) no Debian/Ubuntu.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Rodar sozinho",
            code: "./bin/bootstrap.sh --only tools",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotente?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Sim. Cada ferramenta verifica o PATH antes de instalar; o gerenciador de pacotes é pulado em bloco quando tudo está presente.",
          },
        ],
      },
    ],
  },
  "task-cargo": {
    id: "task-cargo",
    title: "cargo",
    summary: "Toolchain Rust via rustup. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Baixa o rustup-init e roda de um arquivo com --no-modify-path (instaladores nunca tocam ~/.bashrc; PATH vem do bashrc do repo), toolchain stable, perfil minimal. cargo.sh status mostra um relatório sem mudar nada.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Fixar uma toolchain",
            code: "_DOT_RUSTUP_TOOLCHAIN=1.98.0 ./bin/cargo.sh",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotente?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Sim. cargo funcionando pula; a instalação é verificada executando o binário plantado.",
          },
        ],
      },
    ],
  },
  "task-bun": {
    id: "task-bun",
    title: "bun",
    summary: "Runtime Bun + CLI devcontainer. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Instala o binário único do bun a partir do zip oficial (sha256 verificado contra o SHASUMS256.txt do release; o build musl no Alpine) em ~/.local/bin — nunca o install.sh do bun, que editaria ~/.bashrc. Depois instala o CLI devcontainer com bun install --global e o executa com o Bun por um wrapper em ~/.local/bin/devcontainer: sem Node.js.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Fixar uma versão",
            code: "_DOT_BUN_VERSION=bun-v1.2.0 ./bin/bun.sh",
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotente?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Sim. Binários presentes pulam; checksum divergente falha alto sem instalar nada.",
          },
        ],
      },
    ],
  },
  "task-secrets": {
    id: "task-secrets",
    title: "secrets",
    summary:
      "pass + logins de registries de contêiner por ele. Opt-in: --only secrets.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Instala o pass (e o docker-credential-pass onde a distro empacota), confere que você tem uma chave GPG e um store inicializado, e faz todo podman login guardar o token no pass: um drop-in em ~/.config/containers/registries.conf.d, mais um redirecionamento de socket do GnuPG para o helper do Podman rootless alcançar o seu agent. Credenciais de registry em texto plano deixadas em ~/.docker/config.json ou nos auth.json de contêineres são removidas (nomes no log, nunca valores). Pulada por padrão: rode com --only secrets.",
          },
          {
            kind: "code",
            lang: "bash",
            caption:
              "Primeira vez (os dois primeiros passos são seus: sua senha, sua chave)",
            code: "gpg --full-generate-key\npass init <your key id>\n./bin/bootstrap.sh --only secrets\npodman login docker.io",
          },
        ],
      },
      {
        id: "first-setup",
        heading: "Primeira configuração",
        blocks: [
          {
            kind: "ol",
            items: [
              "gpg --full-generate-key — ECC (o padrão), uma validade como 2y, seu nome e email, uma senha forte. O GnuPG também grava um certificado de revogação em ~/.gnupg/openpgp-revocs.d/: guarde uma cópia offline.",
              "gpg --fingerprint voce@exemplo.com — a linha de 40 caracteres abaixo de pub é o fingerprint (público, pode compartilhar).",
              "pass init <fingerprint sem espaços> — cria ~/.password-store para essa chave.",
              "./bin/bootstrap.sh --only secrets, depois podman login <registry> com um token de acesso, nunca a senha da conta.",
            ],
          },
          {
            kind: "code",
            lang: "text",
            caption: "O fingerprint é a segunda linha",
            code: "pub   ed25519 2026-10-15 [SC]\n      3EE7 54D4 94F5 58BB 9B09  F66C FC29 FD31 CC4B 9208\nuid           [ultimate] Your Name <you@example.com>",
          },
        ],
      },
      {
        id: "new-laptop",
        heading: "Mudando para um laptop novo",
        blocks: [
          {
            kind: "p",
            text: "Leve a chave secreta e o store juntos, por SSH ou pendrive — nunca por email, chat ou nuvem: com os dois, tudo descriptografa. Logins de registry não precisam de mais nada; os tokens estão no store. Passo a passo completo: docs/secrets.md.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Laptop antigo (FPR = seu fingerprint)",
            code: 'gpg --export-secret-keys --armor "$FPR" > secret-key.asc\ngpg --export-ownertrust > ownertrust.txt\ntar -czf password-store.tgz -C ~ .password-store',
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Laptop novo",
            code: "gpg --import secret-key.asc\ngpg --import-ownertrust ownertrust.txt\ntar -xzf password-store.tgz -C ~\nshred -u secret-key.asc ownertrust.txt password-store.tgz\n./bin/bootstrap.sh --only secrets",
          },
        ],
      },
      {
        id: "revoke",
        heading: "Revogando",
        blocks: [
          {
            kind: "ul",
            items: [
              "Um token de registry: revogue no registry (Docker Hub: Account settings → Personal access tokens) — é isso que o inutiliza — depois podman logout <registry>.",
              "Sua chave GPG (laptop perdido, chave ou senha vazada): revogue antes todos os tokens do store, depois importe o certificado de revogação da chave, e recomece com chave e tokens novos.",
              "Guarde o certificado de revogação offline e longe da chave: ele revoga sua chave, mas não lê seus segredos.",
            ],
          },
          {
            kind: "code",
            lang: "bash",
            caption:
              "Revogar a chave (o certificado começa com um ':' de proteção — remova antes)",
            code: "cp ~/.gnupg/openpgp-revocs.d/$FPR.rev /tmp/revoke.asc\nsed -i 's/^:-----BEGIN/-----BEGIN/' /tmp/revoke.asc\ngpg --import /tmp/revoke.asc",
          },
        ],
      },
      {
        id: "never",
        heading: "O que nunca faz",
        blocks: [
          {
            kind: "ul",
            items: [
              "Gerar chave GPG, rodar pass init ou pass insert — isso é seu.",
              "Ler, imprimir ou registrar um valor secreto; status e logs só nomeiam registries.",
              "Editar seu registries.conf ou /etc/portage (no Gentoo ela mostra a linha USE=pass).",
            ],
          },
        ],
      },
      {
        id: "idempotent",
        heading: "Idempotente?",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Sim. Sem chave ou store ela para com o comando exato e não muda nada; depois de configurada, rodar de novo não faz nada. Arch, Fedora e Alpine não empacotam o docker-credential-pass: o pass é configurado e a tarefa explica como adicionar o helper.",
          },
        ],
      },
    ],
  },
  "guide-shell": {
    id: "guide-shell",
    title: "Prompt do shell",
    summary: "O prompt bash, utilitários e layout de PATH.",
    sections: [
      {
        id: "prompt",
        heading: "O prompt",
        blocks: [
          {
            kind: "p",
            text: "Três estilos em styles/ compartilham uma biblioteca de coletores (promptlib.sh: estado git, diretório do projeto, marcadores de linguagem, disco e duração). robbyrussell é o padrão: uma seta sensível a erro (verde no sucesso, vermelha na falha), o diretório atual e branch git com marcador dirty — opt-out por repo com git config dottod.hide-dirty 1. Troque com DOT_PROMPT_STYLE=kali ou powerline. Sem plugins, sem frameworks; PROMPT_COMMAND faz o trabalho.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Trocar de estilo",
            code: "DOT_PROMPT_STYLE=kali      # terminal kali em duas linhas\nDOT_PROMPT_STYLE=powerline  # blocos segmentados (precisa de Nerd Font)",
          },
          {
            kind: "code",
            lang: "text",
            caption: "robbyrussell (padrão)",
            code: "➜  dottod git:(feat/prompt-styles) ✗",
          },
          {
            kind: "code",
            lang: "text",
            caption: "kali — # vermelho como root, $ vermelho na falha",
            code: "┌──(user㉿host)-[dottod]\n└─$",
          },
          {
            kind: "code",
            lang: "text",
            caption: "powerline — mostrado com DOT_PROMPT_GLYPHS=ascii",
            code: " user > dottod > feat/prompt-styles ✗    3s ✓ < 09:35 < 27G",
          },
          {
            kind: "callout",
            tone: "info",
            title: "Nerd Font",
            text: "Os separadores do powerline só viram blocos angulados com uma Nerd Font instalada; sem uma, use DOT_PROMPT_GLYPHS=ascii como acima. Os estilos robbyrussell e kali funcionam em qualquer terminal.",
          },
        ],
      },
      {
        id: "path",
        heading: "Layout de PATH",
        blocks: [
          {
            kind: "p",
            text: "~/.local/bin primeiro, depois ~/.bun/bin e ~/.cargo/bin quando existem. Adicionado uma vez por shell — re-sourcing nunca duplica entradas.",
          },
        ],
      },
      {
        id: "utils",
        heading: "Utilitários",
        blocks: [
          {
            kind: "p",
            text: "Bibliotecas scripts/.*.sh carregam aliases (lll, atalhos git, clip, pclip, cclip), funções (mkcd, extract, ff, gr, psg, port, serve, gcl) e o despachante ctr. Só os arquivos ocultos de biblioteca carregam — scripts/*.sh são programas e nunca têm source.",
          },
        ],
      },
      {
        id: "projects",
        heading: "Projetos",
        blocks: [
          {
            kind: "p",
            text: "O alternador codes pula entre projetos git sob CODES_ROOTS (padrão ~/codes:~/code:~/projects:~/src:~/dev:~/work), atividade mais recente primeiro com coluna de status git. Digite codes para o seletor fzf, codes <nome> para pular com correção de typos, codes -l para listar, codes -p para scripts.",
          },
          {
            kind: "p",
            text: "Repos irmãos sob um diretório aparecem como pai/nome, e checkouts de submódulo aninham sob seu superprojeto — cada linha continua sendo um caminho real. Busque pelo pai (codes coparticipacao) ou nome qualificado (codes coparticipacao/front). CODES_GROUP=0 restaura a lista plana, CODES_SUBMODULES=0 descarta checkouts aninhados como antes. Quando existe uma identidade de trabalho (veja gitconfig), uma coluna de contexto marca repositórios de trabalho e pessoais; --work, --personal e --by-context filtram ou agrupam por ele.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Pular entre projetos",
            code: "codes                     # escolhe de tudo\ncodes front               # nomes ambíguos abrem o seletor\ncodes coparticipacao/back # pulo qualificado",
          },
        ],
      },
      {
        id: "updates",
        heading: "Atualizações",
        blocks: [
          {
            kind: "p",
            text: "Shells interativos verificam novos releases do dottod semanalmente: a verificação roda destacada e nunca bloqueia a inicialização, e uma atualização conhecida imprime um aviso com ambas as versões. dottod-update avança um checkout git (instalações via tarball recebem instruções de re-download). DOT_UPDATE_DAYS ajusta o intervalo, DOT_NO_UPDATE_CHECK=1 desativa.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Atualizar o dottod",
            code: "dottod-update",
          },
        ],
      },
      {
        id: "profiles",
        heading: "Perfis Claude",
        blocks: [
          {
            kind: "p",
            text: "O shell oferece perfis Claude Code nomeados (work, personal, …) sobre um armazenamento compartilhado: memória, skills, plugins e projetos ficam em ~/.claude, enquanto cada overlay ~/.claude-<nome> guarda seu próprio login, configurações e diretórios de identidade. claude escolhe o perfil (fzf), claude -P seleciona para a execução, claude-profile gerencia overlays. O painel lateral do seletor mostra conta, plano e uso 5h/7d com horários de reset de cada perfil. A primeira execução monta o overlay; um perfil novo pede /login. Lance sempre pelo wrapper — um /login do claude puro escreve fora dos perfis.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Iniciar com um perfil",
            code: "claude              # escolhe entre os perfis\nclaude -P work      # um perfil para a execução\nclaude-profile add extra  # novo overlay",
          },
        ],
      },
    ],
  },
  "guide-neovim": {
    id: "guide-neovim",
    title: "Neovim",
    summary: "Edição enxuta: perfis, keymaps, health.",
    sections: [
      {
        id: "profiles",
        heading: "Perfis",
        blocks: [
          {
            kind: "table",
            headers: ["Perfil", "Plugins na abertura"],
            rows: [
              [
                "minimal",
                "options, keymaps, colorscheme, statusline (SSH/recuperação)",
              ],
              [
                "terminal",
                "+ gitsigns, toggleterm, lançadores de ferramentas, devcontainer CLI",
              ],
              ["development", "igual a terminal (padrão)"],
              ["full", "igual a terminal"],
            ],
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Escolher um perfil",
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
            headers: ["Teclas", "Faz"],
            rows: [
              ["<C-h/j/k/l>", "navegação de janelas"],
              ["]b [b", "próximo/anterior buffer"],
              ["<leader>tt/th/tv", "terminal flutuante/horizontal/vertical"],
              ["<leader>bt", "btop"],
              ["<leader>Du/Dc/Dd/De", "devcontainer up/connect/down/exec"],
              ["<leader>e/pe", "alternar explorador"],
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
            text: ":checkhealth dottod relata versão, perfil, estado do lazy.nvim com contagem de pins, ferramentas externas e o CLI devcontainer. A bateria headless (scripts/nvim-headless-check.sh) roda as mesmas checagens no CI para cada perfil.",
          },
        ],
      },
    ],
  },
  "guide-ssh": {
    id: "guide-ssh",
    title: "SSH",
    summary: "Config do host GitHub e chaves.",
    sections: [
      {
        id: "merge",
        heading: "Merge seguro",
        blocks: [
          {
            kind: "p",
            text: "A tarefa ssh mescla o bloco github.com obrigatório (HostName, User git, IdentityFile ~/.ssh/github, IdentitiesOnly, AddKeysToAgent) na sua config: chaves faltantes são adicionadas, seus valores nunca mudam, hosts alheios são preservados, e reruns são byte-idênticos.",
          },
        ],
      },
      {
        id: "keys",
        heading: "Chaves",
        blocks: [
          {
            kind: "p",
            text: "Um par ed25519 é gerado em ~/.ssh/github (600/644) só quando nenhuma metade existe. Adicione o .pub ao GitHub uma vez; a tarefa nunca regenera.",
          },
        ],
      },
    ],
  },
  "guide-distributions": {
    id: "guide-distributions",
    title: "Distribuições",
    summary:
      "Debian/Ubuntu, Gentoo, Arch, Fedora e Alpine — e o que foi verificado em cada uma.",
    sections: [
      {
        id: "how",
        heading: "Como funciona",
        blocks: [
          {
            kind: "p",
            text: "Toda tarefa instala pacotes por uma camada só (lib/package.sh): ela lê /etc/os-release e usa o gerenciador de pacotes da própria distribuição, com os nomes reais dos pacotes. Qualquer outra distribuição é recusada antes de um único comando de pacote.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "O que o dottod detectou aqui",
            code: "dottod-doctor | grep distro",
          },
          {
            kind: "p",
            text: "O dottod-fetch imprime esse cartão: a detecção e os nomes de pacote do próprio dottod para este sistema, ou para qualquer arquivo os-release. Com o fastfetch instalado (--extras fastfetch) ele desenha o cartão com o logo real da distribuição — e, neste sistema, acrescenta as linhas de kernel, uptime, CPU e memória do fastfetch; sem ele, ou com --plain, imprime o cartão como texto.",
          },
          {
            kind: "demo",
            gif: "fetch.gif",
            alt: "Gravação de terminal: o cartão dottod-fetch, desenhado pelo fastfetch com o logo de cada distribuição, para Gentoo, Arch, Debian, Fedora e Alpine — distro, família, gerenciador de pacotes, libc e nomes de pacotes — com o estilo de prompt alternando entre powerline, kali e robbyrussell, depois bootstrap --list e um relatório --status.",
            transcript:
              "➜ ./scripts/dottod-fetch.sh --os-release tests/fixtures/os-release/gentoo\n\n(o fastfetch desenha o logo do Gentoo à esquerda do cartão)\ndottod 2.x\n-------------\nDistro            Gentoo 2.18\nFamily            gentoo (emerge)\nLibc              glibc\nShell             bash\nPrompt            powerline\nPackages          \n  git             dev-vcs/git\n  vim             app-editors/vim\n  neovim          app-editors/neovim\n  openssh_client  net-misc/openssh\n  podman          app-containers/podman\n  pass            app-admin/pass\n  bats            dev-util/bats\n\n(o mesmo para Arch, Debian, Fedora e Alpine, alternando o estilo de prompt entre powerline, kali e robbyrussell)\n\n➜ ./bin/bootstrap.sh --list\n➜ ./bin/bootstrap.sh --only tools --extras gh,httpie --status",
          },
        ],
      },
      {
        id: "verified",
        heading: "O que foi verificado",
        blocks: [
          {
            kind: "p",
            text: "Só o que de fato rodou é declarado. Contêineres são imagens descartáveis fixadas, cada tarefa rodada duas vezes; o Ubuntu 24.04 teve só os nomes de pacotes verificados.",
          },
          {
            kind: "matrix",
            columns: [
              { distro: "debian", label: "Debian 13" },
              { distro: "gentoo", label: "Gentoo (OpenRC)" },
              { distro: "arch", label: "Arch" },
              { distro: "fedora", label: "Fedora 42" },
              { distro: "alpine", label: "Alpine 3.22" },
            ],
            rows: [
              {
                label: "shell, vim, gitconfig, ssh, fonts",
                cells: [
                  { state: "ok", note: "contêiner, rodado duas vezes" },
                  { state: "ok", note: "contêiner, rodado duas vezes" },
                  { state: "ok", note: "contêiner, rodado duas vezes" },
                  { state: "ok", note: "contêiner, rodado duas vezes" },
                  { state: "ok", note: "contêiner, rodado duas vezes" },
                ],
              },
              {
                label: "neovim ≥ 0.11",
                cells: [
                  {
                    state: "ok",
                    note: "tarball 0.12.5 (o pacote, 0.10.4, é velho demais)",
                  },
                  { state: "ok", note: "pacote 0.11.7, compilado do fonte" },
                  { state: "ok", note: "pacote 0.12.6" },
                  { state: "ok", note: "pacote 0.11.5" },
                  { state: "ok", note: "pacote 0.11.1" },
                ],
              },
              {
                label: "cargo (rustup)",
                cells: [
                  { state: "ok" },
                  { state: "ok" },
                  { state: "ok" },
                  { state: "ok" },
                  { state: "ok", note: "toolchain musl" },
                ],
              },
              {
                label: "bun",
                cells: [
                  {
                    state: "ok",
                    note: "checksum verificado; CLI devcontainer roda no Bun",
                  },
                  { state: "ok", note: "instalado" },
                  { state: "ok", note: "checksum verificado" },
                  { state: "ok", note: "checksum verificado" },
                  {
                    state: "ok",
                    note: "build musl, checksum verificado; CLI devcontainer roda no Bun",
                  },
                ],
              },
              {
                label: "tools + gh",
                cells: [
                  { state: "ok", note: "gh do repositório apt do GitHub" },
                  {
                    state: "partial",
                    note: "nomes de pacotes resolvem; não rodou",
                  },
                  { state: "ok" },
                  { state: "ok" },
                  { state: "ok" },
                ],
              },
              {
                label: "extra fastfetch",
                cells: [
                  {
                    state: "partial",
                    note: "pacote resolve no Debian 13; não empacotado no Ubuntu antes do 25.04",
                  },
                  {
                    state: "partial",
                    note: "nome do pacote resolve; não rodou",
                  },
                  {
                    state: "partial",
                    note: "nome do pacote resolve; não rodou",
                  },
                  {
                    state: "partial",
                    note: "nome do pacote resolve; não rodou",
                  },
                  {
                    state: "partial",
                    note: "nome do pacote resolve; não rodou",
                  },
                ],
              },
              {
                label: "Podman rootless",
                cells: [
                  { state: "ok", note: "neste host Debian" },
                  { state: "pending", note: "precisa do laptop real (OpenRC)" },
                  { state: "notrun" },
                  { state: "partial", note: "só rootful (contêiner aninhado)" },
                  {
                    state: "partial",
                    note: "só helpers e subids (contêiner aninhado)",
                  },
                ],
              },
              {
                label: "zed (--ui)",
                cells: [
                  { state: "notrun" },
                  { state: "notrun" },
                  { state: "notrun" },
                  { state: "notrun" },
                  {
                    state: "unsupported",
                    note: "o Zed só publica builds glibc",
                  },
                ],
              },
            ],
          },
        ],
      },
      {
        id: "notes",
        heading: "Por distribuição",
        blocks: [
          {
            kind: "ul",
            items: [
              "Debian/Ubuntu: apt-get, índice atualizado uma vez por execução; batcat e fdfind também ganham os nomes bat e fd.",
              'Gentoo: emerge com seu perfil, USE flags e EMERGE_DEFAULT_OPTS intactos; o dottod nunca sincroniza e nunca escreve em /etc/portage. Pacotes podem compilar do fonte; no OpenRC, Podman rootless precisa de rc_cgroup_mode="unified" (o status do container avisa).',
              "Arch: pacman -S --needed, nunca um -Sy sozinho (upgrades parciais); se um pacote não for encontrado, rode pacman -Syu antes. Sem AUR.",
              "Fedora: dnf install -y.",
              "Alpine: instale o bash antes. Bun e rustup usam builds musl; o Neovim vem do apk; o Zed é pulado com o motivo; sem chsh, a tarefa shell mostra o comando usermod.",
            ],
          },
        ],
      },
      {
        id: "check",
        heading: "Confira você mesmo",
        blocks: [
          {
            kind: "code",
            lang: "bash",
            caption:
              "Nomes de pacotes, depois o bootstrap principal duas vezes (Podman, limitado a 3 GiB / 2 CPUs)",
            code: "DOTTOD_TEST_INTEGRATION=1 tests/integration/pkg-resolve.sh gentoo arch\nDOTTOD_TEST_INTEGRATION=1 tests/integration/core-smoke.sh alpine",
          },
        ],
      },
    ],
  },
  "guide-containers": {
    id: "guide-containers",
    title: "Contêineres",
    summary: "Somente Podman rootless.",
    sections: [
      {
        id: "select",
        heading: "Instalação",
        blocks: [
          {
            kind: "code",
            lang: "bash",
            caption: "Instalar e inspecionar",
            code: "./bin/bootstrap.sh --only container\n./bin/container.sh status",
          },
        ],
      },
      {
        id: "vocabulary",
        heading: "Vocabulário de detecção",
        blocks: [
          {
            kind: "p",
            text: "Instalado (binário no PATH) → usável (podman info rootless funciona como você, sem sudo). Binário-existe não é usável: namespaces ou faixas subuid faltantes reportam exatamente isso, alto.",
          },
        ],
      },
    ],
  },
  "guide-secret-commands": {
    id: "guide-secret-commands",
    title: "Segredos em comandos",
    summary:
      "pass-run e loadenv: PATs e chaves de API do pass, só onde são necessários.",
    sections: [
      {
        id: "pass-run",
        heading: "pass-run",
        blocks: [
          {
            kind: "p",
            text: "pass-run VAR=caminho … -- comando dá a cada VAR a primeira linha da entrada, só no ambiente desse comando: nunca no seu shell, na linha de comando ou no histórico, nunca impressa. Um programa de verdade (~/.local/bin/pass-run), então scripts e agentes de IA também podem usar.",
          },
          {
            kind: "code",
            lang: "bash",
            code: "pass insert github/pat\npass-run GH_TOKEN=github/pat -- gh pr list",
          },
        ],
      },
      {
        id: "loadenv",
        heading: "loadenv com valores pass:",
        blocks: [
          {
            kind: "p",
            text: "loadenv [arquivo] exporta linhas CHAVE=valor para o seu shell. Um valor pass:caminho é lido do store, então o .env só nomeia segredos, nunca os guarda. O arquivo é dado, nunca código (sem $(…), sem expansão), e o carregamento é tudo-ou-nada: uma linha ruim ou uma entrada faltando não exporta nada.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: ".env",
            code: "API_URL=https://api.example.com\nGH_TOKEN=pass:github/pat",
          },
        ],
      },
      {
        id: "github",
        heading: "Exemplo: a CLI do GitHub",
        blocks: [
          {
            kind: "p",
            text: "Guarde um token fine-grained (só os repositórios necessários, permissões só-leitura, a validade mais curta) no pass e rode o gh via pass-run: o gh lê GH_TOKEN, que tem precedência sobre o que o gh auth login guardou, então o gh nunca precisa de login próprio. Guia completo: docs/secret-commands.md.",
          },
          {
            kind: "code",
            lang: "bash",
            code: "pass insert github/pat\npass-run GH_TOKEN=github/pat -- gh pr list\npass-run GH_TOKEN=github/pat -- gh run list --limit 5",
          },
          {
            kind: "callout",
            tone: "warning",
            text: "O pass-run entrega o segredo a qualquer coisa depois de -- (pass-run X=… -- env o imprimiria). Quando um script ou agente de IA puder rodá-lo, fixe os comandos que ele pode pôr depois de --, mantenha o pass show fechado para ele e conte com o escopo restrito e a validade curta do token. Os guardrails do Claude Code ficam no repositório ai-gent.",
          },
        ],
      },
    ],
  },
  "guide-fonts": {
    id: "guide-fonts",
    title: "Fontes",
    summary: "Nerd Fonts nível de usuário, sem sudo.",
    sections: [
      {
        id: "install",
        heading: "Instalações nível de usuário",
        blocks: [
          {
            kind: "p",
            text: "Fontes vão para ~/.local/share/fonts (sistema todo só com _DOT_NERDFONT_GLOBAL_INSTALL=1). Dependências instalam dos pacotes da distro só quando realmente faltam — um rerun normal não toca sudo nem rede para fontes presentes.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Conjunto customizado",
            code: "./bin/fonts.sh FiraCode ZedMono",
          },
        ],
      },
      {
        id: "note",
        heading: "Fontes do desktop",
        blocks: [
          {
            kind: "callout",
            tone: "info",
            title: "Sem overrides globais",
            text: "dottod nunca define fontes de interface do GNOME. Só o terminal usa essas faces.",
          },
        ],
      },
    ],
  },
  commands: {
    id: "commands",
    title: "Comandos",
    summary: "Cada flag do bootstrap.sh, gerada do --help.",
    sections: [
      {
        id: "flags",
        heading: "Flags",
        blocks: [
          {
            kind: "table",
            headers: ["Flag", "Faz"],
            rows: [
              ["--only <lista>", "roda só essas tarefas"],
              ["--skip <lista>", "pula essas tarefas"],
              [
                "--extras <lista>",
                "ferramentas opt-in da tarefa tools (gh, httpie, chafa, fastfetch, ou all)",
              ],
              ["--parallel", "roda tarefas concorrentemente"],
              ["--ui", "inclui tarefas GUI (zed)"],
              ["--no-ui", "pula tarefas GUI (o padrão)"],
              ["--yes", "assume sim nos prompts"],
              ["--verbose, -v", "mostra saída completa das tarefas"],
              [
                "--status",
                "imprime o relatório status de cada tarefa selecionada (não muda nada)",
              ],
              ["--list, -l", "lista tarefas e sai"],
              ["--help, -h", "mostra ajuda"],
            ],
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Invocações comuns",
            code: "./bin/bootstrap.sh\n./bin/bootstrap.sh --only shell,tools\n./bin/bootstrap.sh --ui --only zed\n./bin/bootstrap.sh --only tools --extras gh,httpie",
          },
        ],
      },
      {
        id: "status",
        heading: "Relatórios de status",
        maturity: "implemented",
        blocks: [
          {
            kind: "p",
            text: "Toda tarefa responde a status com um relatório somente leitura: o que está instalado, linkado ou configurado, sem instalar, gravar ou perguntar nada. bootstrap.sh --status imprime todos os relatórios e respeita --only, --skip e --ui; uma tarefa sozinha roda como <tarefa>.sh status (fonts.sh status também aceita nomes de fontes).",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Relatórios de status",
            code: "./bin/bootstrap.sh --status\n./bin/bootstrap.sh --status --only ssh,gitconfig\n./bin/ssh.sh status\n./bin/fonts.sh status FiraCode",
          },
          {
            kind: "demo",
            gif: "status-report.gif",
            alt: "Gravação de terminal: bootstrap.sh --status imprimindo os relatórios de shell, vim e tools.",
            transcript:
              "➜ ./bin/bootstrap.sh --status --only shell,vim,tools\n\nShell\n-----\nBash:      GNU bash, version 5.2.37(1)-release (x86_64-pc-linux-gnu)\nLogin:     /bin/bash (bash)\nBashrc:    /home/demo/.bashrc (symlink -> /vhs/config/.custom.bashrc (dottod))\n\nVim\n---\nInstalled: VIM - Vi IMproved 9.1 (2024 Jan 02, compiled May 23 2025 00:48:59)\nVimrc:     /home/demo/.vimrc (missing)\nvim-plug:  missing\nPlugins:   0/0 installed\n\nTools\n-----\nCore:      8/12 present (missing: xclip bats shfmt just)\nExtras:    0/4 present (missing: gh httpie chafa fastfetch)\nSelected:  none (DOT_TOOLS_EXTRA)",
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
            alt: "Gravação de terminal: saída de bootstrap.sh --help, depois a lista de tarefas.",
            transcript:
              "➜ ./bin/bootstrap.sh --help\n\nUsage: bootstrap.sh [options]\n\nBootstraps the workstation by running the dottod task scripts.\n\nOptions:\n  --only <list>      Comma-separated list of tasks to run (default: all)\n  --skip <list>      Comma-separated list of tasks to skip\n  --parallel         Run tasks concurrently instead of sequentially\n  --extras <list>    Opt-in tools for the tools task (gh, httpie, chafa,\n                     fastfetch, or all); default none\n  --ui               Include GUI tasks (zed); default skips them\n  --no-ui            Skip GUI tasks (the default; explicit form of omitting --ui)\n  --yes              Assume yes for prompts\n  --verbose, -v      Stream full task output (default: summarized)\n  --status           Print every selected task's status report (changes\n                     nothing; honours --only, --skip and --ui)\n  --list, -l         List available tasks and exit\n  --help, -h         Show this help\n\n➜ ./bin/bootstrap.sh --list\n\nshell fonts vim neovim container zed gitconfig ssh tools cargo bun secrets",
          },
        ],
      },
    ],
  },
  config: {
    id: "config",
    title: "Configuração",
    summary: "Cada variável _DOT_* e seu padrão.",
    sections: [
      {
        id: "vars",
        heading: "Variáveis",
        blocks: [
          {
            kind: "table",
            headers: ["Variável", "Padrão", "Tarefa"],
            rows: [
              ["_DOT_TARGET_USER", "id -un", "todas"],
              [
                "_DOT_NO_PACKAGES",
                "0 (1 pula instalações de pacotes; testes)",
                "todas",
              ],
              ["DOT_TOOLS_EXTRA", "nenhum (lista ou all)", "tools"],
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
              ["GIT_NAME / GIT_EMAIL", "prompt uma vez", "gitconfig"],
              ["_DOT_SSH_DIR", "~/.ssh", "ssh"],
            ],
          },
        ],
      },
    ],
  },
  concepts: {
    id: "concepts",
    title: "Conceitos",
    summary:
      "O vocabulário compartilhado: Task, Profile, Healing, estados, idempotência.",
    sections: [
      {
        id: "terms",
        heading: "Glossário",
        blocks: [
          {
            kind: "table",
            headers: ["Termo", "Significa", "Não"],
            rows: [
              [
                "Task",
                "uma unidade bin/<id>.sh mais sua entrada de registro",
                "script, job",
              ],
              [
                "Profile",
                "DOTTOD_NVIM_PROFILE: minimal, terminal, development, full",
                "mode, tier",
              ],
              [
                "Healing",
                "instalação tarball opt-in quando o pacote é velho",
                "upgrade",
              ],
              [
                "Idempotency",
                "verificar antes de agir; reruns convergem sem trabalho",
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
    title: "Arquitetura",
    summary: "Topologia atual, stack e o fluxo de release.",
    sections: [
      {
        id: "topology",
        heading: "Topologia",
        blocks: [
          {
            kind: "p",
            text: "Provisionador de estação única. Uma interface — bin/bootstrap.sh — dirige onze scripts de tarefa contra $HOME, o gerenciador de pacotes da distro e ~/.config, escalando uma vez por run via sudo ou doas. Sem servidores, sem bancos; estado vive em symlinks, backups (*.dottod.bak), caches e lockfiles.",
          },
          {
            kind: "code",
            lang: "text",
            caption: "Camadas",
            code: "./bin/bootstrap.sh --only/--skip/--parallel/--ui\n        └─► bin/<tarefa>.sh ─► $HOME, gerenciador de pacotes, ~/.config\n                    (via _priv sudo/doas, cacheado por run)",
          },
        ],
      },
      {
        id: "stack",
        heading: "Stack",
        blocks: [
          {
            kind: "table",
            headers: ["Camada", "Tecnologia"],
            rows: [
              [
                "Orquestração",
                "bash (set -Eeuo pipefail), bin/utils.sh compartilhado",
              ],
              ["Shell", "bash puro, sem frameworks"],
              [
                "Editores",
                "vim + vim-plug; Neovim ≥ 0.11 + lazy.nvim (16 pins)",
              ],
              ["Testes", "suítes BATS + testes de lógica de release"],
              [
                "CI",
                "workflows GitHub: shell, container, neovim, docs, release",
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
        heading: "História",
        blocks: [
          {
            kind: "p",
            text: "A pilha zsh/oh-my-zsh/spaceship, as tarefas desktop e vscode, e o TUI Ratatui foram removidos na revisão terminal-first. A arqueologia completa vive no repositório (docs/product/introspec.md, retrofit.md) — só no repo, não publicada aqui.",
          },
        ],
      },
    ],
  },
  roadmap: {
    id: "roadmap",
    title: "Roteiro",
    summary: "O que entrou na 2.0.0, e como trabalho novo entra na lista.",
    sections: [
      {
        id: "delivered",
        heading: "Entregue na 2.0.0",
        maturity: "implemented",
        blocks: [
          {
            kind: "ul",
            items: [
              "Ações status por tarefa: toda tarefa responde a <tarefa>.sh status com um relatório somente leitura, e bootstrap.sh --status imprime todos (veja Comandos).",
              "Demos de terminal vhs na referência de comandos: bootstrap.sh --help e bootstrap.sh --status, renderizadas de novo pela CI da documentação a cada mudança.",
              "Tradução pt-BR de todos os guias.",
            ],
          },
        ],
      },
      {
        id: "planned",
        heading: "Planejado",
        blocks: [
          {
            kind: "p",
            text: "Nada está planejado agora. Trabalho novo começa como especificação em specs/ e aparece aqui, marcado como Planejado, até ser construído.",
          },
        ],
      },
    ],
  },
};

export const ptBR: DocsContent = {
  ui: {
    siteName: "dottod",
    siteTagline: "Estação Linux, reconstruída por um comando bash puro.",
    skipToContent: "Pular para o conteúdo",
    menu: "Menu",
    close: "Fechar",
    search: "Buscar",
    searchPlaceholder: "Buscar páginas…",
    searchNoResults: "Nenhuma página para “{query}”.",
    searchSuggestions: "Tente “bootstrap”, “neovim” ou “--ui”.",
    language: "Idioma",
    theme: "Tema",
    themeDark: "Mudar para tema escuro",
    themeLight: "Mudar para tema claro",
    breadcrumbHome: "dottod",
    onThisPage: "Nesta página",
    version: "Versão",
    copy: "Copiar",
    copied: "Copiado",
    footerNote:
      "docs do dottod — verdade primeiro, do repositório. Rode o bootstrap quando quiser.",
    nextPage: "Próxima",
    maturityLabels: {
      implemented: "Implementado",
      partial: "Parcialmente implementado",
      planned: "Planejado",
      unavailable: "Indisponível",
      upstream: "Limitação externa",
      na: "N/A",
    },
    matrixLabels: {
      ok: "Verificado",
      partial: "Parcialmente verificado",
      pending: "Pendente",
      notrun: "Não rodou",
      unsupported: "Sem suporte",
      na: "Não se aplica",
    },
    matrixLegend: "Legenda",
    matrixRowHeader: "Tarefa",
    groupLabels: {
      start: "Início",
      tasks: "Tarefas",
      guides: "Guias",
      reference: "Referência",
      project: "Projeto",
    },
    notFoundTitle: "Essa página não existe",
    notFoundText: "As páginas estão listadas à esquerda.",
    backHome: "Voltar à Visão geral",
  },
  pages,
};
