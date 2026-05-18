# long_classpath

100 generated `groovy_library` targets plus one `:consumer` that
lists every one of them in `deps`. Exercises the param-file path
(ISSUE-050): without `use_param_file("@%s", use_always = True)` in
`groovy/private/actions.bzl`, the compile command line for
`:consumer` would exceed Linux's `ARG_MAX` (~131 KB) and fail with
`E2BIG` ("Argument list too long").

```
bazel build //...
```

The 100 source files are emitted by `write_file` (bazel-skylib) at
analysis time — no checked-in noise. `:consumer` imports `Dep0` and
`Dep99` so the compile classpath has to be correct end to end, not
just present in `groovyc`'s arguments.

What this proves: param files emit unconditionally for both compile
(`Groovyc`) and packaging (`GroovySingleJar`) actions; if a future
refactor flipped `use_always = True` to `use_always = False`, this
example would surface the regression as a `E2BIG` build failure on
Linux. (macOS's `ARG_MAX` is larger, but the assertion holds because
CI runs on `ubuntu-latest`.)
