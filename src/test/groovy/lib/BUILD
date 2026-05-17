load("//groovy:groovy.bzl", "groovy_junit_test")

# First real Groovy test target — chapter 9 of v0.1.0.
#
# Exercises //example/src/main/groovy/lib:groovylib end-to-end on the JVM.
# Compile-time correctness is already verified by the chapter-4 hermetic-
# actions rewrite; this target adds execute-time coverage.
#
# Layout note: this BUILD lives at //src/test/groovy/lib instead of under
# //example/. The `groovy_test` macro derives JUnit FQCNs from each source
# File's workspace-relative path, requiring a literal `src/test/groovy/`
# or `src/test/java/` prefix. Generalizing that prefix via a `src_roots`
# attr is ISSUE-025 (deferred to v0.2.0). Until then, this is the only
# layout that works with no edits to `groovy/groovy.bzl`.
#
# Macro choice: `groovy_junit_test` (the JUnit 4 convenience wrapper) is
# the minimum that both compiles the test sources into a `groovy_library`
# and registers them on the runtime classpath of the underlying
# `groovy_test`. The plain `groovy_test` macro derives FQCNs from `srcs`
# but does not compile them, so passing test files through it alone
# yields ClassNotFoundException at runtime.
groovy_junit_test(
    name = "GroovyLibTest",
    tests = ["GroovyLibTest.groovy"],
    deps = [
        "//example/src/main/groovy/lib:groovylib",
    ],
)
