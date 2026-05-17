# override_url

Point `groovy.toolchain` at a corporate mirror by overriding `urls` (and
`integrity` if the mirror serves a re-hashed artifact). README-only:
this repo has one `MODULE.bazel`, so we document the pattern rather
than ship a second module.

```python
groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")

groovy.toolchain(
    name = "groovy",
    version = "4.0.32",
    urls = [
        "https://artifactory.example.corp/binaries/groovy/apache-groovy-binary-{version}.zip",
    ],
    integrity = "sha256-Ck1+wT8AxRMNk0pH/8oCw41x6oCkPDe2KVR82Yb/Wf0=",
)
use_repo(groovy, "groovy_sdk_artifact", "junit_artifact", "spock_artifact", "groovy_toolchains")
register_toolchains("@groovy_toolchains//:all")
```

What to look for: `{version}` substitution happens inside
`groovy_sdk_repository`; the integrity hash is required when the mirror
serves a re-hashed artifact, optional when it serves the canonical one
(the registry entry's hash is used as fallback).
