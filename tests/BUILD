load("@rules_java//java:defs.bzl", "java_binary", "java_library")
load("//groovy:toolchain.bzl", "groovy_deps", "groovy_toolchain")
load(
    ":path_to_class_test.bzl",
    "custom_root_test",
    "default_roots_test",
    "longest_prefix_wins_test",
    "no_match_failure_test",
    "no_match_rule",
)
load(":toolchain_test.bzl", "groovy_deps_rejects_non_java_test", "toolchain_rejects_non_deps_provider_test", "toolchain_round_trip_test")

package(default_visibility = ["//visibility:private"])

# Fixtures -------------------------------------------------------------------

# Stand-in for a real groovyc launcher. `analysistest` never executes it; we
# only need an executable target so `attr.label(executable = True)` resolves
# during analysis. `java_binary` keeps the test free of rules_shell.
java_binary(
    name = "fake_groovyc",
    main_class = "tests.FakeJunit",
    runtime_deps = [":fake_junit"],
)

# Stand-in for the SDK contents. A single empty file is enough at
# analysis time — these tests don't execute the compile action.
filegroup(
    name = "fake_sdk",
    srcs = ["fake_sdk_marker.txt"],
)

filegroup(
    name = "fake_runtime_jar",
    srcs = ["fake_groovy.jar"],
)

# A genuine JavaInfo-providing target so `groovy_deps` analysis succeeds.
java_library(
    name = "fake_junit",
    srcs = ["FakeJunit.java"],
)

# A non-JavaInfo target used as a negative-case input for `groovy_deps`.
filegroup(
    name = "not_a_java_target",
    srcs = ["fake_sdk_marker.txt"],
)

# Round-trip fixtures --------------------------------------------------------

groovy_deps(
    name = "junit_runner_deps",
    dep = ":fake_junit",
    dep_name = "junit_runner",
    tags = ["manual"],
)

groovy_toolchain(
    name = "round_trip_toolchain",
    dep_providers = [":junit_runner_deps"],
    groovyc = ":fake_groovyc",
    runtime_jar = ":fake_runtime_jar",
    sdk = ":fake_sdk",
    tags = ["manual"],
    version = "4.0.32",
)

toolchain_round_trip_test(
    name = "toolchain_round_trip_analysis_test",
    target_under_test = ":round_trip_toolchain",
)

# Negative case: groovy_deps rejects a non-JavaInfo target ------------------

groovy_deps(
    name = "bad_groovy_deps",
    dep = ":not_a_java_target",
    dep_name = "broken",
    tags = ["manual"],
)

groovy_deps_rejects_non_java_test(
    name = "groovy_deps_rejects_non_java_analysis_test",
    target_under_test = ":bad_groovy_deps",
)

# Negative case: groovy_toolchain rejects a non-GroovyDepsInfo entry --------

groovy_toolchain(
    name = "bad_toolchain",
    dep_providers = [":fake_junit"],  # java_library does not provide GroovyDepsInfo
    groovyc = ":fake_groovyc",
    runtime_jar = ":fake_runtime_jar",
    sdk = ":fake_sdk",
    tags = ["manual"],
    version = "4.0.32",
)

toolchain_rejects_non_deps_provider_test(
    name = "toolchain_rejects_non_deps_provider_analysis_test",
    target_under_test = ":bad_toolchain",
)

test_suite(
    name = "all_toolchain_tests",
    tests = [
        ":groovy_deps_rejects_non_java_analysis_test",
        ":toolchain_rejects_non_deps_provider_analysis_test",
        ":toolchain_round_trip_analysis_test",
    ],
)

# path_to_class unit tests (ISSUE-002 + ISSUE-025) ---------------------------

default_roots_test(name = "path_to_class_default_roots_test")

custom_root_test(name = "path_to_class_custom_root_test")

longest_prefix_wins_test(name = "path_to_class_longest_prefix_wins_test")

# Fixture for the no-match analysistest: `path_to_class` fails during
# analysis when given a path that no configured root matches.
no_match_rule(
    name = "path_to_class_no_match_fixture",
    tags = ["manual"],
)

no_match_failure_test(
    name = "path_to_class_no_match_failure_test",
    target_under_test = ":path_to_class_no_match_fixture",
)

test_suite(
    name = "all_path_to_class_tests",
    tests = [
        ":path_to_class_custom_root_test",
        ":path_to_class_default_roots_test",
        ":path_to_class_longest_prefix_wins_test",
        ":path_to_class_no_match_failure_test",
    ],
)
