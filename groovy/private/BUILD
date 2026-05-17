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
