load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

# Toolchain type for Groovy. `groovy_toolchain` instances register against this
# type; `groovy_*` rules resolve via `ctx.toolchains["//groovy:toolchain_type"]`.
toolchain_type(
    name = "toolchain_type",
)

# bzl_library targets for Stardoc. //docs runs `stardoc(...)` against the
# public .bzl files; `deps` expects bzl_library so Stardoc can resolve
# `load()` references during doc extraction.

bzl_library(
    name = "groovy_bzl",
    srcs = ["groovy.bzl"],
    deps = [
        ":rules_java_bzl",
        "//groovy/private:actions_bzl",
    ],
)

bzl_library(
    name = "toolchain_bzl",
    srcs = ["toolchain.bzl"],
    deps = [":rules_java_bzl"],
)

# Stub `bzl_library` wrapping the rules_java public + transitive
# private modules our .bzl files reach via @rules_java//java:defs.bzl.
# Stardoc's doc-extract requires a bzl_library for every transitively
# loaded module; @rules_java does not expose one for
# java/private/proto_support.bzl.
bzl_library(
    name = "rules_java_bzl",
    deps = [
        "@rules_java//java:rules",
        "@rules_java//java/private:proto_support",
    ],
)

bzl_library(
    name = "extensions_bzl",
    srcs = ["extensions.bzl"],
    deps = [
        ":bazel_tools_repo_bzl",
        "//groovy/private:versions_bzl",
        "//groovy/private/repositories:artifacts_bzl",
        "//groovy/private/repositories:hub_bzl",
        "//groovy/private/repositories:sdk_bzl",
    ],
)

# Stub `bzl_library` wrapping the @bazel_tools repository-rule helpers
# that extensions.bzl loads transitively. Stardoc's doc-extract walks
# every `load()` and requires a bzl_library for each module; the
# embedded @bazel_tools BUILD only exports the files via filegroup, so
# we declare a thin bzl_library here to satisfy the resolver.
bzl_library(
    name = "bazel_tools_repo_bzl",
    srcs = [
        "@bazel_tools//tools/build_defs/repo:cache.bzl",
        "@bazel_tools//tools/build_defs/repo:http.bzl",
        "@bazel_tools//tools/build_defs/repo:utils.bzl",
    ],
)
