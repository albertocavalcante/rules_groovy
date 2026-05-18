# Copyright 2026-present Alberto Cavalcante. All rights reserved.
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

"""DEPRECATED: use `@rules_groovy//groovy:defs.bzl` instead.

This file is a back-compat shim that re-exports the toolchain providers
and rules from `defs.bzl`. It will be removed in a future release; update
your `load(...)` statements to point at `defs.bzl`.
"""

load(
    "//groovy:defs.bzl",
    _GroovyDepsInfo = "GroovyDepsInfo",
    _GroovyLibraryInfo = "GroovyLibraryInfo",
    _GroovyToolchainInfo = "GroovyToolchainInfo",
    _groovy_deps = "groovy_deps",
    _groovy_toolchain = "groovy_toolchain",
)

GroovyToolchainInfo = _GroovyToolchainInfo
GroovyDepsInfo = _GroovyDepsInfo
GroovyLibraryInfo = _GroovyLibraryInfo
groovy_toolchain = _groovy_toolchain
groovy_deps = _groovy_deps
