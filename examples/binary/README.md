# binary

A `groovy_binary` runnable via `bazel run`.

```
bazel build //...
bazel run //:app
```

Expected stdout from `bazel run //:app`:

```
hello from groovy_binary
```

What this proves: the Groovy runtime jar is wired onto the binary's
`runtime_deps` automatically (via the macro's reference to
`@groovy_sdk_artifact//:groovy`); the resulting `java_binary` launches
under the JVM with `groovy.lang.GroovyObject` on the classpath.
