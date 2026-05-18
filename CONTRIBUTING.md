# Contributing

This project is a fork of [`bazelbuild/rules_groovy`](https://github.com/bazelbuild/rules_groovy) (marked unmaintained at upstream commit `9f8cd15`). It is now maintained at [`albertocavalcante/rules_groovy`](https://github.com/albertocavalcante/rules_groovy). Contributions are welcome via pull request.

There is no CLA. By opening a PR you license your contribution under the repository's existing [Apache-2.0 license](LICENSE.txt).

## Workflow

`main` is protected. All changes land via pull request, squash-merged fast-forward. Direct pushes to `main` are not used, even by maintainers.

1. Open an issue (or comment on an existing one) before non-trivial work.
2. Branch from `main` using the naming conventions below.
3. Run `bazel test //...` locally before opening the PR.
4. Open the PR; the template auto-populates the pre-merge checklist.
5. Address review; the squash commit message is hand-crafted at merge time and is independent of the PR description.

## Branch naming

Kebab-case slugs, prefixed by intent:

- `fix/<slug>` — bug fixes.
- `feat/<slug>` — new rules, attributes, or user-visible features.
- `chore/<slug>` — deps, formatting, repo hygiene.
- `refactor/<slug>` — internal cleanup, no behavior change.
- `test/<slug>` — test-only changes.
- `docs/<slug>` — documentation only.
- `release/v<x.y.z>` — release prep.

## Commit messages

[Conventional commits](https://www.conventionalcommits.org/). The PR title becomes the squash commit subject, so write the PR title in this form:

```
<type>(<scope>): <subject>
```

Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `build`, `ci`, `perf`. Scope is optional but encouraged (`feat(toolchain): ...`, `fix(actions): ...`).

The squash commit body is hand-written at merge time — keep it crisp, explain what and why, and add a `Refs: #<issue>` footer when applicable.

## CI gates

The required checks on `main`:

- `bazel build` and `bazel test //...` on Bazel 9.x, Linux and macOS, bzlmod mode. These must be green to merge.
- `--lockfile_mode=error` is enforced on the same matrix; `MODULE.bazel.lock` is authoritative and any unexpected re-resolution fails the build.
- The docs regen check rebuilds `//docs:all` and fails if the committed Stardoc output under `docs/` diverges from what the current `.bzl` docstrings produce.
- `buildifier --mode=check --lint=warn` over `groovy/`, `tests/`, `docs/`, `MODULE.bazel`, and `REPO.bazel` (pinned to `bazelbuild/buildtools` v8.5.1). The `examples/` tree is intentionally excluded — each example is its own downstream module.

Bazel 7.x and 8.x cells run for regression signal but are advisory — they do not gate merges.

## Local verification before opening a PR

```
bazel build //...
bazel test //...
bazel build --lockfile_mode=error //...
```

To match the buildifier CI gate, auto-format `.bzl` / `BUILD` / `MODULE.bazel` / `REPO.bazel` files before pushing:

```
buildifier --mode=fix --lint=fix -r groovy tests docs MODULE.bazel REPO.bazel
```

Install with `brew install buildifier` on macOS or `go install github.com/bazelbuild/buildtools/buildifier@v8.5.1` elsewhere. If buildifier surfaces a lint warning that the local change genuinely cannot satisfy (e.g. a `ctx` arg required by Bazel's `rule(implementation = ...)` signature but not read in the body), opt out per-line with `# buildifier: disable=<rule>` and leave a one-line justification — don't disable rules repo-wide.

If you changed any `.bzl` docstrings, also run:

```
bazel build //docs:all
cp bazel-bin/docs/rules-public.md docs/rules-public.md
cp bazel-bin/docs/rules-toolchain.md docs/rules-toolchain.md
cp bazel-bin/docs/rules-extension.md docs/rules-extension.md
```

and commit the regenerated files.

## CHANGELOG

User-visible changes (new rules, new attributes, behavior changes, deprecations, removals) need an entry under `[Unreleased]` in [CHANGELOG.md](CHANGELOG.md). Internal refactors, CI tweaks, and docs-only changes do not.

## Reporting bugs and requesting features

Use the issue forms under [`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE/). The bug form asks for Bazel version, OS, JDK, Groovy version, and a minimal repro — including these up front avoids a round-trip.
