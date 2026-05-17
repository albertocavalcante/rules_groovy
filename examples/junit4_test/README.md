# junit4_test

A `groovy_junit_test` against the legacy JUnit 4 runner
(`org.junit.runner.JUnitCore`). Pins Groovy 2.5 so the
`SPOCK_FOR_GROOVY` map resolves to Spock 1.3, which runs under JUnit 4
— the extension's Spock-2-on-Groovy-4 auto-promotion to JUnit 5 does
not fire on this code path.

```
bazel test //...
```

What this proves: the JUnit 4 wire-up still works for downstream
consumers that pin a Groovy line older than 3.0. Source uses
`@org.junit.Test` and `org.junit.Assert.assertEquals`.
