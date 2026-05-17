load("//groovy:groovy.bzl", "groovy_binary")

# Runnable via `bazel run //example/binary:app`. The Groovy runtime jar
# is added to `runtime_deps` automatically by the macro, so the BUILD
# does not depend on `@groovy_sdk_artifact` explicitly.
groovy_binary(
    name = "app",
    srcs = ["src/main/groovy/app/App.groovy"],
    main_class = "app.App",
)
