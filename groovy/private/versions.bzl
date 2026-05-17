"""Pinned versions and integrity hashes for every artifact this ruleset downloads.

Single source of truth. Consumers (the module extension, repository rules, the
toolchain) read from here so URL/SHA pairs never duplicate.

Integrity is expressed as `sha256-<base64>` per RFC 9110, the form Bazel 9
prefers over hex `sha256`. To update an entry by hand:

    curl -sL <url> | openssl dgst -sha256 -binary | base64

then prefix with `sha256-`. A `tools/update_versions.py` helper that automates
this is planned for Phase 2.
"""

# Known Groovy SDK distributions. Keyed by full version string.
# `url_template`, `strip_prefix`, and `lib_jar` use `{version}` substitution
# so adding a new patch release means one row, not five.
GROOVY_VERSIONS = {
    "2.5.23": struct(
        integrity = "sha256-f6NgKERXobr13phBWMWR9pAMGQKc6KwhMq16kDTIdfU=",
        url_template = "https://archive.apache.org/dist/groovy/{version}/distribution/apache-groovy-binary-{version}.zip",
        strip_prefix = "groovy-{version}",
        lib_jar = "lib/groovy-{version}.jar",
        min_jdk = "8",
    ),
    "3.0.25": struct(
        integrity = "sha256-V0LyoIc6aZ171y90hiaDfES+7VdgJsNCq21NEhQ+ISQ=",
        url_template = "https://archive.apache.org/dist/groovy/{version}/distribution/apache-groovy-binary-{version}.zip",
        strip_prefix = "groovy-{version}",
        lib_jar = "lib/groovy-{version}.jar",
        min_jdk = "8",
    ),
    "4.0.32": struct(
        integrity = "sha256-8D6IOLVsIC2Mhk1GL2EX01Ev220dua/NR9/Rr4FoP1A=",
        url_template = "https://archive.apache.org/dist/groovy/{version}/distribution/apache-groovy-binary-{version}.zip",
        strip_prefix = "groovy-{version}",
        lib_jar = "lib/groovy-{version}.jar",
        min_jdk = "11",
    ),
}

# Default Groovy version when a user writes `groovy.toolchain()` with no
# version override. Bumped to the modern 4.0.x line in chapter 6 of the
# v0.1.0 release narrative. Users staying on the legacy 2.5.x line pin
# explicitly: `groovy.toolchain(version = "2.5.23")`. The cascade in
# `SPOCK_FOR_GROOVY` below picks the matching `spock-core:2.3-groovy-4.0`
# jar automatically; the implicit `groovy.testing(junit = "4")` default
# keeps JUnit at 4.13.2.
DEFAULT_GROOVY_VERSION = "4.0.32"

# JUnit 4 + its single transitive dep, hamcrest-core. Used when a `testing`
# tag selects `junit = "4"` (the default for Groovy 2.5, paired with Spock 1.3).
JUNIT4 = struct(
    artifacts = {
        "hamcrest-core": struct(
            coord = "org.hamcrest:hamcrest-core:1.3",
            url = "https://repo1.maven.org/maven2/org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3.jar",
            integrity = "sha256-Zv3vkelzk0jfeglqo4SlaF9Oh1WEzOiThqekclHE2Ok=",
        ),
        "junit": struct(
            coord = "junit:junit:4.13.2",
            url = "https://repo1.maven.org/maven2/junit/junit/4.13.2/junit-4.13.2.jar",
            integrity = "sha256-jklbY0Rp1k+4rPo0laBly6zIoP/1XOHjEAe+TBbcV9M=",
        ),
    },
    runner_class = "org.junit.runner.JUnitCore",
)

# JUnit 5: Jupiter 5.14.4 (API + engine) on top of Platform 1.14.4
# (commons + engine + launcher + console) plus the two transitive deps
# opentest4j and apiguardian-api. Selected when a `testing` tag specifies
# `junit = "5"`. The console artifact (named `junit-platform-console-launcher`
# in earlier JUnit 5 releases) is the CLI entry point; the FQCN of the runner
# main class is unchanged.
JUNIT5 = struct(
    artifacts = {
        "apiguardian-api": struct(
            coord = "org.apiguardian:apiguardian-api:1.1.2",
            url = "https://repo1.maven.org/maven2/org/apiguardian/apiguardian-api/1.1.2/apiguardian-api-1.1.2.jar",
            integrity = "sha256-tQlEisUG1gcxnxglN/CzXXEAdYLsdBgyofER5bW3Czg=",
        ),
        "junit-jupiter-api": struct(
            coord = "org.junit.jupiter:junit-jupiter-api:5.14.4",
            url = "https://repo1.maven.org/maven2/org/junit/jupiter/junit-jupiter-api/5.14.4/junit-jupiter-api-5.14.4.jar",
            integrity = "sha256-qhrghf2S39v4XYZ+YOWa3FmbrBg7Rvx+BpgZi/QmrT8=",
        ),
        "junit-jupiter-engine": struct(
            coord = "org.junit.jupiter:junit-jupiter-engine:5.14.4",
            url = "https://repo1.maven.org/maven2/org/junit/jupiter/junit-jupiter-engine/5.14.4/junit-jupiter-engine-5.14.4.jar",
            integrity = "sha256-4eNc9lGuFjVjjUMepEEtXGWTi+VBUERPB7pllYYEKxE=",
        ),
        "junit-platform-commons": struct(
            coord = "org.junit.platform:junit-platform-commons:1.14.4",
            url = "https://repo1.maven.org/maven2/org/junit/platform/junit-platform-commons/1.14.4/junit-platform-commons-1.14.4.jar",
            integrity = "sha256-VcigwGmsG8Th+Luya16ulcvRDk/xsjJIRBq2GmBzgeE=",
        ),
        "junit-platform-console": struct(
            coord = "org.junit.platform:junit-platform-console:1.14.4",
            url = "https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console/1.14.4/junit-platform-console-1.14.4.jar",
            integrity = "sha256-j7opWpqs7WEwYreoSGdYtxQY4VRaN3XejfntdswGI4M=",
        ),
        "junit-platform-engine": struct(
            coord = "org.junit.platform:junit-platform-engine:1.14.4",
            url = "https://repo1.maven.org/maven2/org/junit/platform/junit-platform-engine/1.14.4/junit-platform-engine-1.14.4.jar",
            integrity = "sha256-PH8/hKZ0eu8Ntr1f3Spsj+NxMuZTyTm9Zzhzd69m2Rw=",
        ),
        "junit-platform-launcher": struct(
            coord = "org.junit.platform:junit-platform-launcher:1.14.4",
            url = "https://repo1.maven.org/maven2/org/junit/platform/junit-platform-launcher/1.14.4/junit-platform-launcher-1.14.4.jar",
            integrity = "sha256-do1i8bKlI3E7cC21NgnCMK9iu9ZF/CwHp9eU302jIig=",
        ),
        "opentest4j": struct(
            coord = "org.opentest4j:opentest4j:1.3.0",
            url = "https://repo1.maven.org/maven2/org/opentest4j/opentest4j/1.3.0/opentest4j-1.3.0.jar",
            integrity = "sha256-SOLfY2yrZWPO1k3N/4q7I1VifLI27wvzdZhoLd90Lxs=",
        ),
    },
    runner_class = "org.junit.platform.console.ConsoleLauncher",
)

# Spock varies per Groovy major.minor: Spock 1.3 is the last release on
# JUnit 4 and the only one that works against Groovy 2.5; Spock 2.x runs on
# JUnit 5 and ships a separate jar per Groovy target (`-groovy-3.0`,
# `-groovy-4.0`) because the bytecode-level API differs across Groovy majors.
SPOCK_FOR_GROOVY = {
    "2.5": struct(
        coord = "org.spockframework:spock-core:1.3-groovy-2.5",
        integrity = "sha256-Tlx4jOW6wL2kHNBmSFzoSrUOMYLYGmeJuCo+JlzYX5A=",
        junit_flavor = "4",
    ),
    "3.0": struct(
        coord = "org.spockframework:spock-core:2.3-groovy-3.0",
        integrity = "sha256-ct9M21y7FRmlMUeolpPb6ORncY5gyydshc1d4OYbltE=",
        junit_flavor = "5",
    ),
    "4.0": struct(
        coord = "org.spockframework:spock-core:2.3-groovy-4.0",
        integrity = "sha256-YKYUp2QMT8nf1DKSmkJr0ESPKZkVkkVWrjchBaEY/xQ=",
        junit_flavor = "5",
    ),
}
