<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Module extension exposing rules_groovy's user-facing MODULE.bazel API.

Two tag classes:

  * `groovy.toolchain(name, version, urls, integrity, strip_prefix, lib_jar)`
    — registers a downloaded SDK. All attrs except `name` and `version` are
    optional overrides; empty values fall back to the registry entry for
    `version`. Unknown versions require all four download fields and fail
    loudly otherwise.
  * `groovy.local_toolchain(name, sdk_path, version, lib_jar)` — registers
    an SDK already present on disk; no download.

When no tag is declared, an implicit `groovy.toolchain()` fires so the
minimal three-line MODULE.bazel works:

    groovy = use_extension("//groovy:extensions.bzl", "groovy")
    use_repo(groovy, "groovy_toolchains")
    register_toolchains("@groovy_toolchains//:all")

The extension emits:
  * one `groovy_sdk_repository` / `groovy_local_sdk_repository` per
    registered toolchain (default repo name `groovy_sdk_artifact` for the
    implicit default; `<tag.name>_sdk` for explicit tags so multi-version
    builds get predictable names);
  * a `@groovy_toolchains` hub repo with `groovy_toolchain` and
    `toolchain(...)` per SDK.

Test framework jars (JUnit, Spock, etc.) are not managed by this
extension. Resolve them in your own MODULE.bazel via
`rules_jvm_external`'s `maven.install` and pass the resulting labels
through `groovy_junit5_test(deps = ...)` etc. See
`examples/junit5_external/` for the canonical wiring.

`extension_metadata(reproducible = True)` is always returned: the
*graph* the extension produces is a pure function of MODULE.bazel + the
private versions.bzl pins. URL-override-without-integrity degrades only
the affected repo (`rctx.repo_metadata(reproducible = False)` in
`sdk.bzl`) rather than the whole extension, mirroring the rules_python
pattern at `python_repository.bzl:227-235`.

<a id="groovy"></a>

## groovy

<pre>
groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")
groovy.toolchain(<a href="#groovy.toolchain-name">name</a>, <a href="#groovy.toolchain-integrity">integrity</a>, <a href="#groovy.toolchain-lib_jar">lib_jar</a>, <a href="#groovy.toolchain-strip_prefix">strip_prefix</a>, <a href="#groovy.toolchain-urls">urls</a>, <a href="#groovy.toolchain-version">version</a>)
groovy.local_toolchain(<a href="#groovy.local_toolchain-name">name</a>, <a href="#groovy.local_toolchain-lib_jar">lib_jar</a>, <a href="#groovy.local_toolchain-sdk_path">sdk_path</a>, <a href="#groovy.local_toolchain-version">version</a>)
</pre>

Configures Groovy SDKs and registered toolchains.

Two tag classes — `toolchain`, `local_toolchain` — plus an implicit
default so the minimal MODULE.bazel is three lines:

    groovy = use_extension("//groovy:extensions.bzl", "groovy")
    use_repo(groovy, "groovy_toolchains")
    register_toolchains("@groovy_toolchains//:all")

Test framework jars are not managed by this extension. Resolve them
via `rules_jvm_external`'s `maven.install` and pass the labels through
`groovy_junit5_test(deps = ...)` etc. See `examples/junit5_external/`.


**TAG CLASSES**

<a id="groovy.toolchain"></a>

### toolchain

Registers a downloaded Groovy SDK toolchain.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="groovy.toolchain-name"></a>name |  Logical name; becomes the SDK repo name suffix (<name>_sdk) and the toolchain target name.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | optional |  `"groovy"`  |
| <a id="groovy.toolchain-integrity"></a>integrity |  Subresource integrity (sha256-<base64>). Empty falls back to the registry entry.   | String | optional |  `""`  |
| <a id="groovy.toolchain-lib_jar"></a>lib_jar |  Path to the runtime jar inside the SDK. Empty falls back to the registry entry.   | String | optional |  `""`  |
| <a id="groovy.toolchain-strip_prefix"></a>strip_prefix |  Top-level directory inside the zip. Empty falls back to the registry entry.   | String | optional |  `""`  |
| <a id="groovy.toolchain-urls"></a>urls |  Mirror URL list; supports '{version}' substitution. Empty falls back to the registry entry.   | List of strings | optional |  `[]`  |
| <a id="groovy.toolchain-version"></a>version |  Groovy version, e.g. '4.0.32'. Empty falls back to DEFAULT_GROOVY_VERSION.   | String | optional |  `""`  |

<a id="groovy.local_toolchain"></a>

### local_toolchain

Registers an existing Groovy SDK from a filesystem path; no download.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="groovy.local_toolchain-name"></a>name |  Logical name; becomes the SDK repo name and the toolchain target name.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="groovy.local_toolchain-lib_jar"></a>lib_jar |  Path to the runtime jar relative to sdk_path, e.g. 'lib/groovy-4.0.24.jar'.   | String | required |  |
| <a id="groovy.local_toolchain-sdk_path"></a>sdk_path |  Filesystem path to an existing Groovy SDK (absolute or workspace-relative).   | String | required |  |
| <a id="groovy.local_toolchain-version"></a>version |  Version string for diagnostics and the SDK directory name.   | String | required |  |


