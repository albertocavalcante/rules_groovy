load("@rules_java//java:defs.bzl", "java_binary", "java_library")
load("//groovy:defs.bzl", "groovy_library", "groovy_toolchain")
load(":hermeticity_test.bzl", "hermeticity_test")
load(
    ":path_to_class_test.bzl",
    "custom_root_test",
    "default_roots_test",
    "longest_prefix_wins_test",
    "no_match_failure_test",
    "no_match_rule",
)
load(":toolchain_test.bzl", "toolchain_round_trip_test")

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

# A genuine JavaInfo-providing target kept around for hermeticity coverage
# and potential future toolchain-attr negative tests.
java_library(
    name = "fake_junit",
    srcs = ["FakeJunit.java"],
)

# Round-trip fixture --------------------------------------------------------

groovy_toolchain(
    name = "round_trip_toolchain",
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

test_suite(
    name = "all_toolchain_tests",
    tests = [
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

# Hermeticity coverage (PR #28) ---------------------------------------------
#
# A tiny real groovy_library so the analysistest can introspect the
# Groovyc + GroovySingleJar actions via `analysistest.target_actions`.
groovy_library(
    name = "hermeticity_fixture",
    srcs = ["HermeticityFixture.groovy"],
    tags = ["manual"],
)

hermeticity_test(
    name = "hermeticity_analysis_test",
    target_under_test = ":hermeticity_fixture",
)

test_suite(
    name = "all_hermeticity_tests",
    tests = [
        ":hermeticity_analysis_test",
    ],
)
