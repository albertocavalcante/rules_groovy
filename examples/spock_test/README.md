# spock_test

A `spock_test` against Spock 2.3 (matched to Groovy 4.0 by the
`SPOCK_FOR_GROOVY` table). Spock 2.x discovers specs via the JUnit
Platform engine; the extension auto-promotes the testing flavor to
JUnit 5 and points the toolchain's `runner_class` at
`org.junit.platform.console.ConsoleLauncher`.

```
bazel test //...
```

What this proves: the Spock 2.x + JUnit 5 Platform composition runs end
to end. Data-driven specs (`where:` blocks, the `expect:` matrix) report
through the JUnit Platform.
