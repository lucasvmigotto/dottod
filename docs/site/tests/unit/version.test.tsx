import { screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { footerVersions } from "../../scripts/footer-versions";
import { App } from "../../src/App";
import { harness } from "../a11y/harness";

const base = {
  repoUrl: "https://github.com/o/r",
  name: "r",
  docsVersion: "0.1.0",
  docsPath: "docs/site",
};
const sha = "abc1234def5678";

describe("footerVersions", () => {
  it("links a release build to its tag", () => {
    const v = footerVersions({
      ...base,
      git: { exactTag: "1.8.0", lastTag: "1.8.0", sha },
    });
    expect(v.map((x) => x.label)).toEqual(["r@v1.8.0", "docs@v0.1.0"]);
    expect(v.map((x) => x.href)).toEqual([
      "https://github.com/o/r/tree/1.8.0",
      "https://github.com/o/r/tree/1.8.0/docs/site",
    ]);
  });

  it("marks a build past the tag with its commit", () => {
    const v = footerVersions({
      ...base,
      git: { exactTag: "", lastTag: "1.8.0", sha },
    });
    expect(v.map((x) => x.label)).toEqual([
      "r@v1.8.0+abc1234",
      "docs@v0.1.0+abc1234",
    ]);
    expect(v[0]?.href).toBe(`https://github.com/o/r/tree/${sha}`);
  });

  it("reads dev before the first tag, and has no link without git", () => {
    const untagged = footerVersions({
      ...base,
      git: { exactTag: "", lastTag: "", sha },
    });
    expect(untagged[0]?.label).toBe("r@dev+abc1234");
    const nogit = footerVersions({
      ...base,
      git: { exactTag: "", lastTag: "", sha: "" },
    });
    expect(nogit.map((x) => x.label)).toEqual(["r@dev", "docs@v0.1.0"]);
    expect(nogit.every((x) => x.href === null)).toBe(true);
  });
});

describe("footer", () => {
  it("shows each version linked to its tree", () => {
    harness(<App />, "/");
    expect(screen.getByTitle("Versions")).toHaveTextContent(
      "dottod@v1.8.0 · docs@v0.1.0",
    );
    expect(screen.getByRole("link", { name: "dottod@v1.8.0" })).toHaveAttribute(
      "href",
      "https://github.com/lucasvmigotto/dottod/tree/1.8.0",
    );
  });
});
