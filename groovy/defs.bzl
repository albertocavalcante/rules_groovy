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

"""Public Groovy build rules.

Single load surface for every user-facing symbol in this ruleset:

  * Macros: `groovy_library`, `groovy_and_java_library`, `groovy_binary`,
    `groovy_test`, `groovy_junit_test`, `groovy_junit5_test`, `spock_test`.
  * Rules: `groovy_runtime`, `groovy_toolchain`, `groovy_deps`.
  * Providers: `GroovyToolchainInfo`, `GroovyDepsInfo`, `GroovyLibraryInfo`.
  * Helpers: `path_to_class`.

Every symbol is re-exported from a single-responsibility `.bzl` under
`groovy/private/`. Downstream BUILD files should `load("@rules_groovy//groovy:defs.bzl", ...)`
for everything.
"""

load("//groovy/private:binary.bzl", _groovy_binary = "groovy_binary")
load(
    "//groovy/private:library.bzl",
    _groovy_and_java_library = "groovy_and_java_library",
    _groovy_library = "groovy_library",
)
load("//groovy/private:runtime.bzl", _groovy_runtime = "groovy_runtime")
load(
    "//groovy/private:test.bzl",
    _groovy_junit5_test = "groovy_junit5_test",
    _groovy_junit_test = "groovy_junit_test",
    _groovy_test = "groovy_test",
    _path_to_class = "path_to_class",
    _spock_test = "spock_test",
)
load(
    "//groovy/private:toolchain.bzl",
    _GroovyDepsInfo = "GroovyDepsInfo",
    _GroovyLibraryInfo = "GroovyLibraryInfo",
    _GroovyToolchainInfo = "GroovyToolchainInfo",
    _groovy_deps = "groovy_deps",
    _groovy_toolchain = "groovy_toolchain",
)

# Macros and rules ----------------------------------------------------------

groovy_library = _groovy_library
groovy_and_java_library = _groovy_and_java_library
groovy_binary = _groovy_binary
groovy_runtime = _groovy_runtime
groovy_test = _groovy_test
groovy_junit_test = _groovy_junit_test
groovy_junit5_test = _groovy_junit5_test
spock_test = _spock_test

# Toolchain rules -----------------------------------------------------------

groovy_toolchain = _groovy_toolchain
groovy_deps = _groovy_deps

# Providers -----------------------------------------------------------------

GroovyToolchainInfo = _GroovyToolchainInfo
GroovyDepsInfo = _GroovyDepsInfo
GroovyLibraryInfo = _GroovyLibraryInfo

# Helpers -------------------------------------------------------------------

path_to_class = _path_to_class
