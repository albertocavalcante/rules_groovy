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

"""Module extension for Groovy SDK.

This extension provides bzlmod support for rules_groovy. It internally calls
the same groovy_toolchains() function used by WORKSPACE builds, ensuring
consistent behavior across both build systems.

Usage in MODULE.bazel:
    groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")
    use_repo(groovy, "groovy_sdk_artifact", "junit_artifact", "spock_artifact")
"""

load("//groovy:toolchains.bzl", "groovy_toolchains")

def _groovy_impl(module_ctx):
    """Implementation of the groovy module extension.

    Calls groovy_toolchains() with register=False since native.bind()
    is not available in bzlmod mode.
    """
    groovy_toolchains(register = False)
    return module_ctx.extension_metadata(reproducible = True)

groovy = module_extension(
    implementation = _groovy_impl,
    doc = """Configures Groovy SDK and test dependencies.

Instantiates repositories for the Groovy SDK, JUnit, and Spock test framework.
These repositories are then made available via use_repo().

Example:
    groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")
    use_repo(groovy, "groovy_sdk_artifact", "junit_artifact", "spock_artifact")
""",
)
