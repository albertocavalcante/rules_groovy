# Copyright 2019-2024 The Bazel Authors. All rights reserved.
# Copyright 2025-present Alberto Cavalcante. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Unified toolchain setup for WORKSPACE and bzlmod.

This module provides a unified API for setting up Groovy toolchains that works
with both WORKSPACE and bzlmod build systems.

WORKSPACE usage:
    load("@rules_groovy//groovy:toolchains.bzl", "groovy_toolchains")
    groovy_toolchains()

bzlmod usage (via extensions.bzl):
    groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")
    use_repo(groovy, "groovy_sdk_artifact", "junit_artifact", "spock_artifact")
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:jvm.bzl", "jvm_maven_import_external")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_GROOVY_VERSION = "2.5.8"
_GROOVY_SHA256 = "49fb14b98f9fed1744781e4383cf8bff76440032f58eb5fabdc9e67a5daa8742"

_GROOVY_BUILD_FILE = """
filegroup(
    name = "sdk",
    srcs = glob(["groovy-2.5.8/**"]),
    visibility = ["//visibility:public"],
)
java_import(
    name = "groovy",
    jars = ["groovy-2.5.8/lib/groovy-2.5.8.jar"],
    visibility = ["//visibility:public"],
)
"""

def groovy_toolchains(
        name = "rules_groovy_toolchains",
        groovy_version = _GROOVY_VERSION,
        register = True):
    """Instantiates Groovy toolchains and dependencies.

    This is the unified API that works for both WORKSPACE and bzlmod.
    The bzlmod extension calls this with register=False, while WORKSPACE
    users should call it with register=True (the default).

    Args:
        name: Name of generated toolchains repository (unused currently,
            reserved for future toolchain registration)
        groovy_version: Groovy SDK version to use
        register: Whether to create native.bind() aliases for WORKSPACE
            compatibility. Set to True for WORKSPACE, False for bzlmod.
    """

    # Groovy SDK
    maybe(
        http_archive,
        name = "groovy_sdk_artifact",
        urls = [
            "https://archive.apache.org/dist/groovy/{0}/distribution/apache-groovy-binary-{0}.zip".format(groovy_version),
        ],
        sha256 = _GROOVY_SHA256,
        build_file_content = _GROOVY_BUILD_FILE,
    )

    # JUnit
    maybe(
        jvm_maven_import_external,
        name = "junit_artifact",
        artifact = "junit:junit:4.12",
        server_urls = ["https://repo1.maven.org/maven2"],
        licenses = ["notice"],
        artifact_sha256 = "59721f0805e223d84b90677887d9ff567dc534d7c502ca903c0c2b17f05c116a",
    )

    # Spock
    maybe(
        jvm_maven_import_external,
        name = "spock_artifact",
        artifact = "org.spockframework:spock-core:1.3-groovy-2.5",
        server_urls = ["https://repo1.maven.org/maven2"],
        licenses = ["notice"],
        artifact_sha256 = "4e5c788ce5bac0bda41cd066485ce84ab50e3182d81a6789b82a3e265cd85f90",
    )

    # Bindings for WORKSPACE backward compatibility (//external:groovy-sdk, etc.)
    # These provide aliases that some external users may depend on.
    # The core groovy.bzl rules now use canonical @repo labels directly,
    # so these bindings are optional but kept for compatibility.
    if register:
        native.bind(name = "groovy-sdk", actual = "@groovy_sdk_artifact//:sdk")
        native.bind(name = "groovy", actual = "@groovy_sdk_artifact//:groovy")
        native.bind(name = "junit", actual = "@junit_artifact//jar")
        native.bind(name = "spock", actual = "@spock_artifact//jar")

def groovy_register_toolchains():
    """Registers Groovy toolchains. Call after groovy_toolchains().

    Currently a no-op as rules_groovy doesn't define custom toolchains yet.
    Reserved for future toolchain registration.
    """
    pass
