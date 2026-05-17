# multi_version

Two `groovy.toolchain` declarations coexist in the same module; targets
resolve through whichever toolchain Bazel selects on the configured
platform. README-only: a single `MODULE.bazel` per repo means we cannot
host the parallel setup as a separate root, but the snippet below is
what a consumer would write.

```python
groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")

groovy.toolchain(
    name = "groovy3",
    version = "3.0.21",
)

groovy.toolchain(
    name = "groovy4",
    version = "4.0.32",
)

use_repo(
    groovy,
    "groovy3_sdk",
    "groovy4_sdk",
    "junit_artifact",
    "spock_artifact",
    "groovy_toolchains",
)
register_toolchains("@groovy_toolchains//:all")
```

What to look for: each explicit `groovy.toolchain` tag is materialized
as `<name>_sdk` (here `groovy3_sdk` and `groovy4_sdk`); the hub repo
emits one `groovy_toolchain` + `toolchain(...)` per SDK so
`register_toolchains("@groovy_toolchains//:all")` stays a one-liner.
Spock follows the first resolved SDK's Groovy major.minor unless
overridden via `groovy.testing(spock_label = ...)`.
