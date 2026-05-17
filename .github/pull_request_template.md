<!--
Thanks for the PR. The fields below are what reviewers need to merge.
Keep the summary tight, mark the type, and tick the checklist as you go.
The PR title (not this body) becomes the squash commit subject — please
write it as a conventional-commits header, e.g.
  feat(toolchain): expose dep_providers on groovy_toolchain
-->

### Summary

<!-- One or two sentences: what changes and why. -->

### Type

- [ ] feat
- [ ] fix
- [ ] chore
- [ ] refactor
- [ ] docs
- [ ] test
- [ ] build
- [ ] ci
- [ ] perf

### Checklist

- [ ] Conventional-commits title and squash subject
- [ ] `bazel test //...` green on Bazel 9.x locally
- [ ] `--lockfile_mode=error` clean
- [ ] Docs regenerated (`bazel build //docs:all`) if `.bzl` docstrings changed
- [ ] CHANGELOG entry added under `[Unreleased]` for user-visible changes

### Notes

<!-- Anything else: tradeoffs, follow-ups, screenshots, related issues. -->
