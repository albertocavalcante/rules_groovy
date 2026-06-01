# Copyright 2026-present Alberto Cavalcante. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0

# Package for repository-rule implementations used by the module extension.
# The .bzl files are loaded directly from //groovy:extensions.bzl; the
# bzl_library targets below exist purely so Stardoc (//docs) can resolve
# transitive loads during doc extraction.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

bzl_library(
    name = "hub_bzl",
    srcs = ["hub.bzl"],
)

bzl_library(
    name = "sdk_bzl",
    srcs = ["sdk.bzl"],
)
