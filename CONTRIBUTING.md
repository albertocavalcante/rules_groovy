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

The required checks on PRs and `main`:

- `bzlmod / ubuntu-latest / Bazel 9.x` — `bazel build` + `bazel test //...` with `--lockfile_mode=error`. `MODULE.bazel.lock` is authoritative; any unexpected re-resolution fails the build.
- `examples / <name>` — each `examples/<name>/` is its own Bazel module that exercises `rules_groovy` as a downstream consumer.
- `buildifier` — `--mode=check --lint=warn` over `groovy/`, `tests/`, `docs/`, `MODULE.bazel`, and `REPO.bazel` (pinned to `bazelbuild/buildtools` v8.5.1). The `examples/` tree is intentionally excluded — each example is its own downstream module.
- `docs regen check` — rebuilds `//docs:all` and fails if the committed Stardoc output under `docs/` diverges from what the current `.bzl` docstrings produce.

### macOS, advisory cells, and the release recipe

To keep the GitHub Actions budget honest (see ISSUE-078), the following do NOT run on PRs:

- `bzlmod / macos-latest / Bazel 9.x` — macOS minutes are 10x linux. Runs weekly on cron (Mondays 03:17 UTC) and on manual `workflow_dispatch`.
- `bzlmod / {ubuntu,macos} / Bazel {7.x,8.x} (advisory)` — Bazel-9-only is the supported baseline per ADR-005. The four advisory cells live in a `build-advisory` job that runs only when `workflow_dispatch` is fired with `run_advisory=true`.

**Before tagging any release**, fire the full historical matrix via the GitHub UI ("Actions → CI → Run workflow") or the CLI:

```
gh workflow run CI --ref main --field run_advisory=true
```

That single dispatch exercises the macOS Bazel 9 cell **and** the four advisory cells (Bazel 7 / 8 × Linux / macOS), giving full pre-release confidence without paying for it per-PR.

## Local verification before opening a PR

The repo's `.bazelrc` defines a `--config=ci` aggregate that mirrors what CI runs (`--lockfile_mode=error`, sane terminal/colour settings, `--test_output=errors` for tests). Pair it with `--config=disk-cache` to use the same on-disk action cache as CI.

```
bazel build --config=ci --config=disk-cache //...
bazel test  --config=ci --config=disk-cache //...
```

Plain `bazel build //...` also works for quick local checks; you'll lose the strict lockfile gate and the disk-cache routing, but the prebuilt-protoc flag (set unconditionally at the top of `.bazelrc`) and the `remotejdk_11` Java runtime still apply.

### Remote cache (optional)

If you have a cache URL and bearer token, the rc comment block at the bottom of `.bazelrc` shows the flag set to pass at the command line. Read-write requires the token; read-only flips `--remote_upload_local_results=false`.

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
