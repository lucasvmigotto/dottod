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
      subtitle: "Reconstrua uma estação Debian com um comando bash puro.",
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
            text: "dottod são dotfiles pessoais e bootstrap de estação Debian. Um ponto de entrada — bin/bootstrap.sh — executa doze tarefas idempotentes: shell, fontes, editores, runtime de contêineres, terminal, ferramentas CLI e SSH do GitHub. Cada tarefa verifica antes de agir, faz backup do que substitui e relata PASS ou FAIL com um log por tarefa.",
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
              ["container", "Podman padrão, Docker alternativo"],
              ["zed", "editor Zed (GUI, opt-in)"],
              ["ghostty", "terminal Ghostty (GUI, opt-in)"],
              ["gitconfig", "identidade Git"],
              ["ssh", "merge do host GitHub + chave ed25519"],
              [
                "tools",
                "lazygit, lazydocker, k9s, btop, httpie, bat, resterm, xclip, chafa, fzf, gh, shellcheck, bats, shfmt, just",
              ],
              ["cargo", "toolchain Rust via rustup"],
              ["bun", "runtime Bun + CLI devcontainer"],
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
            text: "Você precisa de Debian (ou derivado) com apt, mais sudo ou doas. Se o sudo não for passwordless, a senha é pedida uma vez; senão rode como root. Tarefas GUI (zed, ghostty) são puladas por padrão — passe --ui para incluí-las.",
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
              "Reinstale o Debian e clone este repositório.",
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
    summary: "As doze tarefas: o que cada uma faz e se é seguro repetir.",
    sections: [
      {
        id: "all",
        heading: "Todas as tarefas",
        blocks: [
          {
            kind: "table",
            headers: ["Tarefa", "Seguro repetir", "Precisa"],
            rows: [
              ["shell", "Sim", "apt (git, bash)"],
              ["fonts", "Sim", "nada quando presentes"],
              ["vim", "Sim", "rede só para plugins faltantes"],
              ["neovim", "Sim", "apt ou tarball (0.11+)"],
              ["container", "Sim", "apt na primeira vez"],
              ["zed", "Sim (opt-in)", "rede"],
              ["ghostty", "Sim (opt-in)", "rede"],
              ["gitconfig", "Sim", "GIT_NAME/GIT_EMAIL uma vez"],
              ["ssh", "Sim", "nada (chave uma vez)"],
              ["tools", "Sim", "apt + releases do GitHub"],
              ["cargo", "Sim", "rede uma vez"],
              ["bun", "Sim", "rede uma vez"],
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
            text: "Instala Neovim (apt quando o candidato é ≥ 0.11, senão falha com instruções), liga ~/.config/nvim ao repositório (configs existentes viram backup, nunca deletadas), e deixa o lazy.nvim sincronizar 16 plugins fixos na primeira abertura. Perfis via DOTTOD_NVIM_PROFILE: minimal, terminal, development (padrão), full.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Curar via tarball quando o apt é velho",
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
                "0.10.4 via apt abaixo do mínimo",
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
    summary: "Podman padrão, Docker quando escolhido. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Resolve podman, docker ou auto (nunca troca silenciosamente uma escolha explícita), garante Podman rootless (uidmap + faixas subuid/subgid) ou delega ao instalador Docker. container.sh status mostra seleção/instalação/usabilidade sem mudar nada.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Escolher e inspecionar",
            code: "./bin/bootstrap.sh --runtime docker --only container\n./bin/container.sh status",
          },
          {
            kind: "demo",
            gif: "status-commands.gif",
            alt: "Gravação de terminal: relatórios de container.sh status e cargo.sh status.",
            transcript:
              "➜ ./bin/container.sh status\n\nContainer runtime\n-----------------\nConfigured: <unset> (default: podman)\nSelected:   podman\nPodman:     installed 5.4.2\nDocker:     missing\nRootless:   yes\nUsable:     yes\n\n➜ ./bin/cargo.sh status\n\nRust toolchain\n--------------\nCargo:    cargo 1.98.0 (797e8a9bc 2026-08-05)\nHome:     /home/lucas/.cargo\nProfile:  minimal (default for fresh installs)\nToolchain: stable (default for fresh installs)\nRustup:   present",
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
  "task-ghostty": {
    id: "task-ghostty",
    title: "ghostty",
    summary: "Terminal Ghostty + padrão. Opt-in com --ui. Seguro repetir.",
    sections: [
      {
        id: "what",
        heading: "O que faz",
        blocks: [
          {
            kind: "p",
            text: "Roda o instalador ghostty-ubuntu de um arquivo baixado (nunca pipe em shell privilegiado), depois define o Ghostty como terminal padrão do GNOME e alternativa x-terminal-emulator.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Rodar sozinho",
            code: "./bin/bootstrap.sh --ui --only ghostty",
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
            text: "Sim. ghostty presente pula a instalação; o terminal padrão reaplica. Pulado sem --ui.",
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
            text: "Define user.name e user.email a partir de GIT_NAME/GIT_EMAIL, da config global existente, ou de um prompt no TTY — depois escreve ~/.gitconfig (com backup). Valores iguais são deixados intactos: sem backup, sem reescrita.",
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Não interativo",
            code: 'GIT_NAME="Seu Nome" GIT_EMAIL="voce@exemplo.com" ./bin/gitconfig.sh',
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
            text: "Instala btop, httpie, chafa, xclip, bat, jq, curl, tar, ca-certificates, lsof, fzf, shellcheck, bats, shfmt e just via apt (pulado quando tudo presente), gh do repositório apt oficial (keyring assinado), e lazygit, lazydocker, k9s e resterm dos releases do GitHub — verificados por sha256 contra a API, com aviso-e-segue quando não publicado.",
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
            text: "Sim. Cada ferramenta verifica PATH-ou-destino antes de baixar; apt é pulado em bloco quando satisfeito.",
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
            text: "Instala o binário único do bun a partir do zip oficial (sha256 verificado, avisa quando não há digest) em ~/.local/bin — nunca o install.sh do bun, que editaria ~/.bashrc. Depois instala o CLI devcontainer com bun install --global (precisa de node; instalado via apt só quando falta).",
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
            text: "~/.local/bin primeiro, depois ~/.opencode/bin, ~/.bun/bin e ~/.cargo/bin quando existem. Adicionado uma vez por shell — re-sourcing nunca duplica entradas.",
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
            text: "Repos irmãos sob um diretório aparecem como pai/nome, e checkouts de submódulo aninham sob seu superprojeto — cada linha continua sendo um caminho real. Busque pelo pai (codes coparticipacao) ou nome qualificado (codes coparticipacao/front). CODES_GROUP=0 restaura a lista plana, CODES_SUBMODULES=0 descarta checkouts aninhados como antes.",
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
            text: "O shell oferece perfis Claude Code nomeados (work, personal, …) sobre um armazenamento compartilhado: memória, skills, plugins e projetos ficam em ~/.claude, enquanto cada overlay ~/.claude-<nome> guarda seu próprio login, configurações e diretórios de identidade. claude escolhe o perfil (fzf), claude -P seleciona para a execução, claude-profile gerencia overlays. A primeira execução monta o overlay; um perfil novo pede /login. Lance sempre pelo wrapper — um /login do claude puro escreve fora dos perfis.",
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
              ["<leader>gg/dk/kk/bt", "lazygit, lazydocker, k9s, btop"],
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
  "guide-containers": {
    id: "guide-containers",
    title: "Contêineres",
    summary: "Podman padrão, Docker quando escolhido.",
    sections: [
      {
        id: "select",
        heading: "Seleção",
        blocks: [
          {
            kind: "table",
            headers: ["Valor", "Significado"],
            rows: [
              ["podman", "Usar Podman (padrão)"],
              ["docker", "Usar Docker (alternativa explícita)"],
              ["auto", "Podman se usável, senão Docker, senão Podman"],
            ],
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Escolher e inspecionar",
            code: "_DOT_CONTAINER_RUNTIME=docker ./bin/bootstrap.sh --only container\n./bin/container.sh status",
          },
        ],
      },
      {
        id: "vocabulary",
        heading: "Vocabulário de detecção",
        blocks: [
          {
            kind: "p",
            text: "Configurado (valor do env) → instalado (binário no PATH) → usável (funciona como você, sem sudo) → selecionado (resolução). Binário-existe não é usável: daemon parado ou namespaces faltantes reportam exatamente isso, alto.",
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
            text: "Fontes vão para ~/.local/share/fonts (sistema todo só com _DOT_NERDFONT_GLOBAL_INSTALL=1). Dependências instalam via apt só quando realmente faltam — um rerun normal não toca sudo nem rede para fontes presentes.",
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
              ["--runtime <nome>", "podman, docker ou auto (padrão podman)"],
              ["--parallel", "roda tarefas concorrentemente"],
              ["--ui", "inclui tarefas GUI (zed, ghostty)"],
              ["--no-ui", "pula tarefas GUI (o padrão)"],
              ["--yes", "assume sim nos prompts"],
              ["--verbose, -v", "mostra saída completa das tarefas"],
              ["--list, -l", "lista tarefas e sai"],
              ["--help, -h", "mostra ajuda"],
            ],
          },
          {
            kind: "code",
            lang: "bash",
            caption: "Invocações comuns",
            code: "./bin/bootstrap.sh\n./bin/bootstrap.sh --only shell,tools\n./bin/bootstrap.sh --ui --only zed\n./bin/bootstrap.sh --skip ghostty,zed",
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
              "➜ ./bin/bootstrap.sh --help\n\nUsage: bootstrap.sh [options]\n\nBootstraps the workstation by running the dottod task scripts.\n\nOptions:\n  --only <list>      Comma-separated list of tasks to run (default: all)\n  --skip <list>      Comma-separated list of tasks to skip\n  --runtime <name>   Container runtime: podman, docker, or auto (default: podman)\n  --parallel         Run tasks concurrently instead of sequentially\n  --ui               Include GUI tasks (zed, ghostty); default skips them\n  --no-ui            Skip GUI tasks (the default; explicit form of omitting --ui)\n  --yes              Assume yes for prompts\n  --verbose, -v      Stream full task output (default: summarized)\n  --list, -l         List available tasks and exit\n  --help, -h         Show this help\n\n➜ ./bin/bootstrap.sh --list\n\nshell fonts vim neovim container zed ghostty gitconfig ssh tools cargo bun",
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
              ["_DOT_NO_PACKAGES", "0 (1 pula apt; testes)", "todas"],
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
                "Configured / Selected / Usable",
                "escolha explícita vs resolução automática vs runtime funcionando",
                "—",
              ],
              [
                "Healing",
                "instalação tarball opt-in quando o apt é velho",
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
            text: "Provisionador de estação única. Uma interface — bin/bootstrap.sh — dirige doze scripts de tarefa contra $HOME, /etc/apt e ~/.config, escalando uma vez por run via sudo ou doas. Sem servidores, sem bancos; estado vive em symlinks, backups (*.dottod.bak), caches e lockfiles.",
          },
          {
            kind: "code",
            lang: "text",
            caption: "Camadas",
            code: "./bin/bootstrap.sh --only/--skip/--parallel/--ui\n        └─► bin/<tarefa>.sh ─► $HOME, /etc/apt, ~/.config\n                    (via _priv sudo/doas, cacheado por run)",
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
    summary: "O que está especificado mas não construído.",
    maturity: "planned",
    sections: [
      {
        id: "planned",
        heading: "Planejado",
        maturity: "planned",
        blocks: [
          {
            kind: "p",
            text: "Estes itens existem como especificações, não código. Estão aqui para o status ser honesto — nada abaixo é apresentado como funcionando.",
          },
          {
            kind: "ul",
            items: [
              "Ações status por tarefa (superfície uniforme de verificação).",
              "Demos de terminal vhs para a referência de comandos.",
              "Tradução pt-BR dos guias restantes.",
            ],
          },
        ],
      },
      {
        id: "decisions",
        heading: "Deliberadamente fora",
        blocks: [
          {
            kind: "ul",
            items: [
              "LSP, Treesitter, formatadores e linters na config Neovim (removidos por design).",
              "Instalador one-liner do dottod (um curl|sh flagship contradiz a postura download-then-run).",
              "Histórias multi-usuário ou de time (escopo single-user, confirmado).",
            ],
          },
        ],
      },
    ],
  },
};

export const ptBR: DocsContent = {
  ui: {
    siteName: "dottod",
    siteTagline: "Estação Debian, reconstruída por um comando bash puro.",
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
