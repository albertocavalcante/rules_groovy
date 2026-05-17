# Static default groovy_toolchain.
#
# Chapter 4 of the v0.1.0 release narrative wires `groovy_*` rules to
# `ctx.toolchains["//groovy:toolchain_type"]`. Toolchain resolution needs an
# actual registered toolchain or analysis fails. This file declares one,
# pointing at @groovy_sdk_artifact (the repo created by the existing
# `groovy/toolchains.bzl::groovy_toolchains()` macro, invoked from
# `groovy/extensions.bzl`).
#
# Chapter 5 deletes this directory entirely and replaces it with
# module-extension-driven registration (`groovy.toolchain` /
# `groovy.local_toolchain` tag classes). It is deliberately temporary.

load("//groovy:toolchain.bzl", "groovy_toolchain")

package(default_visibility = ["//visibility:public"])

groovy_toolchain(
    name = "groovy_default",
    groovyc = "@groovy_sdk_artifact//:groovyc",
    runtime_jar = "@groovy_sdk_artifact//:runtime_jar",
    sdk = "@groovy_sdk_artifact//:sdk",
    version = "2.5.8",
    # JUnit / Spock are still wired through each rule's `deps` attribute for
    # chapter 4. Chapter 5 routes them through `dep_providers` via the
    # `groovy.testing` tag class.
    dep_providers = [],
)

toolchain(
    name = "groovy_default_toolchain",
    toolchain = ":groovy_default",
    toolchain_type = "@rules_groovy//groovy:toolchain_type",
)
