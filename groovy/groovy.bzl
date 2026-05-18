# Copyright 2015-2024 The Bazel Authors. All rights reserved.
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

This file is a back-compat shim that re-exports the public macros and
rules from `defs.bzl`. It will be removed in a future release; update
your `load(...)` statements to point at `defs.bzl`.
"""

load(
    "//groovy:defs.bzl",
    _groovy_and_java_library = "groovy_and_java_library",
    _groovy_binary = "groovy_binary",
    _groovy_junit5_test = "groovy_junit5_test",
    _groovy_junit_test = "groovy_junit_test",
    _groovy_library = "groovy_library",
    _groovy_runtime = "groovy_runtime",
    _groovy_test = "groovy_test",
    _path_to_class = "path_to_class",
    _spock_test = "spock_test",
)

groovy_library = _groovy_library
groovy_and_java_library = _groovy_and_java_library
groovy_binary = _groovy_binary
groovy_runtime = _groovy_runtime
groovy_test = _groovy_test
groovy_junit_test = _groovy_junit_test
groovy_junit5_test = _groovy_junit5_test
spock_test = _spock_test
path_to_class = _path_to_class
