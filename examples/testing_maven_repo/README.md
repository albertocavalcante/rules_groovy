# testing_maven_repo

Demonstrates the `groovy.testing(maven_repo = ...)` override —
points the test-runtime artifact fetch (JUnit, Spock, Hamcrest,
opentest4j, apiguardian, JUnit-5 platform) at a different Maven base
URL. The default is `https://repo1.maven.org/maven2`; in a corporate
setup you'd swap in an internal Artifactory or Nexus mirror.

```python
groovy.testing(
    junit = "5",
    spock = True,
    maven_repo = "https://artifactory.corp.example.com/maven-central",
)
```

This example uses the same URL as the default so the build runs end-
to-end without an internal mirror. The override mechanism is
exercised the same way; substituting any other URL that mirrors
Maven Central works identically (integrity verification is the
gate).

```sh
bazel test //...
```

For finer-grained overrides — replacing individual artifacts as
labels rather than a whole base URL — `groovy.testing` accepts
`junit_label`, `junit_api_label`, `junit_engine_label`,
`hamcrest_label`, and `spock_label`. Any `JavaInfo`-providing label
works, including `rules_jvm_external`-resolved Maven targets. That
shape isn't demoed here; see the `## Examples` table in the parent
README for the related per-version override examples
(`override_url`, `custom_version`).
