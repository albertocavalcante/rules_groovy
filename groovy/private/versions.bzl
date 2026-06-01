"""Pinned versions and integrity hashes for every artifact this ruleset downloads.

Single source of truth. The module extension and SDK repository rule
read from here so URL/SHA pairs never duplicate.

Integrity is expressed as `sha256-<base64>` per RFC 9110, the form Bazel 9
prefers over hex `sha256`. To update an entry by hand:

    curl -sL <url> | openssl dgst -sha256 -binary | base64

then prefix with `sha256-`. A `tools/update_versions.py` helper that automates
this is planned for Phase 2.

Test framework jars (JUnit, Spock, etc.) are not pinned here. They are
user concerns, typically resolved via `rules_jvm_external`'s
`maven.install` in the consumer's MODULE.bazel — see
`examples/junit5_external/` for the canonical wiring.
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
# version override. Users on the legacy 2.5.x line pin explicitly:
# `groovy.toolchain(version = "2.5.23")`.
DEFAULT_GROOVY_VERSION = "4.0.32"
