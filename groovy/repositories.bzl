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

"""WORKSPACE dependency loading for rules_groovy.

This module provides the WORKSPACE-compatible API for loading rules_groovy
dependencies. It internally calls groovy_toolchains() which is the unified
API shared with bzlmod.

Usage in WORKSPACE:
    load("@rules_groovy//groovy:repositories.bzl", "rules_groovy_dependencies")
    rules_groovy_dependencies()
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//groovy:toolchains.bzl", "groovy_toolchains")

def rules_groovy_dependencies():
    """Fetches all dependencies for rules_groovy.

    This is the main entry point for WORKSPACE users. It loads rules_java
    and then calls groovy_toolchains() to set up the Groovy SDK and test
    dependencies.

    Usage:
        load("@rules_groovy//groovy:repositories.bzl", "rules_groovy_dependencies")
        rules_groovy_dependencies()
    """

    # bazel_skylib is required by many Bazel 8 dependencies
    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "fa01292859726603e3cd3a0f3f29625e68f4d2b165647c72908045027473e933",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.8.0/bazel-skylib-1.8.0.tar.gz",
        ],
    )

    # bazel_features is required by rules_java 8.x
    maybe(
        http_archive,
        name = "bazel_features",
        sha256 = "2cd9e57d4c38675d321731d65c15258f3a66438ad531ae09cb8bb14217dc8572",
        strip_prefix = "bazel_features-1.11.0",
        urls = [
            "https://github.com/bazel-contrib/bazel_features/releases/download/v1.11.0/bazel_features-v1.11.0.tar.gz",
        ],
    )

    # Load rules_java dependency (version compatible with Bazel 8)
    maybe(
        http_archive,
        name = "rules_java",
        urls = [
            "https://github.com/bazelbuild/rules_java/releases/download/8.5.0/rules_java-8.5.0.tar.gz",
        ],
        sha256 = "5c215757b9a6c3dd5312a3cdc4896cef3f0c5b31db31baa8da0d988685d42ae4",
    )

    # Set up Groovy toolchains with WORKSPACE bindings
    groovy_toolchains(register = True)
