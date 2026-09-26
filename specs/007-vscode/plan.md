# 007-vscode — as-is technical context

- Entry: `bin/vscode.sh` (keyrings dir → `gpg --dearmor` key → signed
  `vscode.list` → apt install `code`) [OBSERVED: bin/vscode.sh:20].
- External trust: `https://packages.microsoft.com/keys/microsoft.asc`
  (dearmored, `signed-by`, `chmod a+r`) [OBSERVED: bin/vscode.sh:21].
- No dedicated test suite (shellcheck/bash -n only).
