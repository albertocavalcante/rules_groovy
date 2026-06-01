# junit5_external

Demonstrates the **recommended** way to wire JUnit 5 into a
`groovy_junit5_test`: user-resolved Maven artifacts via
`rules_jvm_external`, passed as `deps`. The Groovy toolchain ships only
the SDK; test framework jars are the user's concern.

```python
# MODULE.bazel
maven = use_extension("@rules_jvm_external//:extensions.bzl", "maven")
maven.install(
    artifacts = [
        "org.junit.jupiter:junit-jupiter-api:5.11.0",
        "org.junit.jupiter:junit-jupiter-engine:5.11.0",
        "org.junit.platform:junit-platform-console:1.11.0",
    ],
    lock_file = "//:maven_install.json",
    repositories = ["https://repo1.maven.org/maven2"],
)
use_repo(maven, "maven")

groovy.testing(junit = "none", spock = False)
```

```python
# BUILD.bazel
groovy_junit5_test(
    name = "GreeterTest",
    tests = ["src/test/groovy/lib/GreeterTest.groovy"],
    deps = [
        ":lib",
        "@maven//:org_junit_jupiter_junit_jupiter_api",
        "@maven//:org_junit_jupiter_junit_jupiter_engine",
        "@maven//:org_junit_platform_junit_platform_console",
    ],
)
```

```sh
bazel test //...
```

## Why this shape

The other test examples (`junit4_test`, `junit5_test`, `spock_test`)
opt into the built-in `groovy.testing(...)` defaults — convenient,
but rules_groovy ends up doing Maven resolution that
[`rules_jvm_external`](https://github.com/bazel-contrib/rules_jvm_external)
already does better:

  - Full transitive resolution captured in a committed lockfile.
  - `REPIN=1 bazel run @maven//:pin` to bump versions without editing
    Starlark.
  - Native corporate-mirror support (`repositories = [...]`).
  - Per-test version flexibility (different test suites can pull
    different JUnit minors if needed).

The internal `groovy.testing` extension goes away in the v0.1
breaking-change pass; this example is the destination pattern.

## Air-gapped / corporate mirror

Swap the `repositories` list for your internal Artifactory or Nexus:

```python
maven.install(
    artifacts = [...],
    lock_file = "//:maven_install.json",
    repositories = ["https://artifactory.corp.example.com/maven-central"],
)
```

The lockfile pins per-artifact SHAs, so the mirror only has to serve
bit-identical jars.
