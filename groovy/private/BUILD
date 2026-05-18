load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

# The wrapper script consumed by `@groovy_sdk_artifact//:groovyc` (an
# `sh_binary`) — see groovy/toolchains.bzl's `_GROOVY_BUILD_FILE`. Public
# visibility is necessary because the consumer lives in a generated repo
# outside `//groovy/private/...`.
exports_files(["groovyc_wrapper.sh"])

# bzl_library targets so Stardoc (//docs) can resolve transitive loads
# during doc extraction. No public API here.

bzl_library(
    name = "actions_bzl",
    srcs = ["actions.bzl"],
    deps = [
        "//groovy:rules_java_bzl",
    ],
)

bzl_library(
    name = "versions_bzl",
    srcs = ["versions.bzl"],
)

bzl_library(
    name = "toolchain_bzl",
    srcs = ["toolchain.bzl"],
    deps = ["//groovy:rules_java_bzl"],
)

bzl_library(
    name = "runtime_bzl",
    srcs = ["runtime.bzl"],
    deps = [
        ":actions_bzl",
        "//groovy:rules_java_bzl",
    ],
)

bzl_library(
    name = "library_bzl",
    srcs = ["library.bzl"],
    deps = [
        ":actions_bzl",
        ":runtime_bzl",
        ":toolchain_bzl",
        "//groovy:rules_java_bzl",
    ],
)

bzl_library(
    name = "binary_bzl",
    srcs = ["binary.bzl"],
    deps = [
        ":library_bzl",
        ":runtime_bzl",
        "//groovy:rules_java_bzl",
    ],
)

bzl_library(
    name = "test_bzl",
    srcs = ["test.bzl"],
    deps = [
        ":actions_bzl",
        ":library_bzl",
        "//groovy:rules_java_bzl",
    ],
)
