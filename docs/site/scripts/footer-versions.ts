// The footer's versions: dottod's release, then the site's own
// (package.json), each linked to the repository tree it was built from —
// `dottod@v1.8.0 · docs@v0.1.0`; past a tag, `dottod@v1.8.0+abc1234`
// linked to the commit; without git, plain text.
export interface GitInfo {
  exactTag: string;
  lastTag: string;
  sha: string;
}

export interface FooterVersion {
  name: string;
  version: string;
  label: string;
  href: string | null;
}

// `name@vX.Y.Z` (the "v" is display-only), or `name@dev…` before any release.
export function label(name: string, version: string): string {
  return /^\d/.test(version) ? `${name}@v${version}` : `${name}@${version}`;
}

export function footerVersions(opts: {
  repoUrl: string;
  name: string;
  docsVersion: string;
  docsPath: string;
  git: GitInfo;
}): FooterVersion[] {
  const { exactTag, lastTag, sha } = opts.git;
  const short = sha.slice(0, 7);
  const ref = exactTag || sha;
  const project = exactTag || (sha ? `${lastTag || "dev"}+${short}` : "dev");
  const docs =
    exactTag || !sha ? opts.docsVersion : `${opts.docsVersion}+${short}`;
  const tree = ref ? `${opts.repoUrl}/tree/${ref}` : null;
  return [
    {
      name: opts.name,
      version: project,
      label: label(opts.name, project),
      href: tree,
    },
    {
      name: "docs",
      version: docs,
      label: label("docs", docs),
      href: tree && `${tree}/${opts.docsPath}`,
    },
  ];
}
