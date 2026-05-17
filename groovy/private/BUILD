package(default_visibility = ["//visibility:public"])

# The wrapper script consumed by `@groovy_sdk_artifact//:groovyc` (an
# `sh_binary`) — see groovy/toolchains.bzl's `_GROOVY_BUILD_FILE`. Public
# visibility is necessary because the consumer lives in a generated repo
# outside `//groovy/private/...`.
exports_files(["groovyc_wrapper.sh"])
