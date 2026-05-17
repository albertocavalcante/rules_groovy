# local_sdk

Use a Groovy SDK already present on disk via `groovy.local_toolchain`.
README-only: a `sdk_path` only exists on the user's filesystem, so we
document the pattern rather than ship a vendored SDK in the repo.

```python
groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")

groovy.local_toolchain(
    name = "groovy_local",
    sdk_path = "/opt/groovy-4.0.24",
    version = "4.0.24",
    lib_jar = "lib/groovy-4.0.24.jar",
)
use_repo(groovy, "groovy_local", "junit_artifact", "spock_artifact", "groovy_toolchains")
register_toolchains("@groovy_toolchains//:all")
```

What to look for: `local_toolchain` skips the network entirely — no
`http_archive`, no integrity hash, no `urls`. The `sdk_path` is read
verbatim; the `lib_jar` is the runtime jar's location relative to that
path. Useful in air-gapped environments and when pinning to a custom
SDK build.
