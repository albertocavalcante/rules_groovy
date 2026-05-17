# rules_jvm_external_interop

Route JUnit and Spock test deps through `@maven`-resolved labels
instead of the pinned `http_jar` defaults. `rules_groovy` does not
depend on `rules_jvm_external`; the user resolves the Maven coordinates
in their own `MODULE.bazel` and passes the resulting labels via
`groovy.testing(*_label = ...)`. README-only: this repo's default
testing path is the pinned one, so we document the opt-in.

```python
bazel_dep(name = "rules_jvm_external", version = "6.5")

maven = use_extension("@rules_jvm_external//:extensions.bzl", "maven")
maven.install(
    name = "maven",
    artifacts = [
        "junit:junit:4.13.2",
        "org.spockframework:spock-core:2.3-groovy-4.0",
    ],
)
use_repo(maven, "maven")

groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")
groovy.toolchain()
groovy.testing(
    junit_label = "@maven//:junit_junit",
    spock_label = "@maven//:org_spockframework_spock_core",
)
use_repo(groovy, "groovy_sdk_artifact", "junit_artifact", "spock_artifact", "groovy_toolchains")
register_toolchains("@groovy_toolchains//:all")
```

What to look for: any `*_label` you set must already provide `JavaInfo`
(any `java_library`, `java_import`, or RJE-generated target qualifies).
`rules_groovy` itself never loads `rules_jvm_external`; mixing pinned
defaults with overrides prints one info-level diagnostic at extension
time so version-skew bugs stay debuggable.

See `notes/maven-decoupling.md` in the planning repo for the full
design.
