<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public Groovy build rules.

Single load surface for every user-facing symbol in this ruleset:

  * Macros: `groovy_library`, `groovy_and_java_library`, `groovy_binary`,
    `groovy_test`, `groovy_junit_test`, `groovy_junit5_test`, `spock_test`.
  * Rules: `groovy_runtime`, `groovy_toolchain`.
  * Providers: `GroovyToolchainInfo`, `GroovyLibraryInfo`.
  * Helpers: `path_to_class`.

Every symbol is re-exported from a single-responsibility `.bzl` under
`groovy/private/`. Downstream BUILD files should `load("@rules_groovy//groovy:defs.bzl", ...)`
for everything.

<a id="groovy_toolchain"></a>

## groovy_toolchain

<pre>
load("@rules_groovy//groovy:defs.bzl", "groovy_toolchain")

groovy_toolchain(<a href="#groovy_toolchain-name">name</a>, <a href="#groovy_toolchain-groovyc">groovyc</a>, <a href="#groovy_toolchain-runtime_jar">runtime_jar</a>, <a href="#groovy_toolchain-sdk">sdk</a>, <a href="#groovy_toolchain-version">version</a>)
</pre>

Defines a Groovy toolchain: compiler, SDK file set, runtime jar, and version string.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="groovy_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="groovy_toolchain-groovyc"></a>groovyc |  The groovyc launcher target (script or in-process driver). Read via ctx.executable.groovyc.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="groovy_toolchain-runtime_jar"></a>runtime_jar |  The groovy-X.Y.Z.jar to place on the runtime classpath.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="groovy_toolchain-sdk"></a>sdk |  Filegroup containing the full Groovy SDK contents.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="groovy_toolchain-version"></a>version |  Resolved SDK version string, e.g. '4.0.32'. Diagnostics only.   | String | required |  |


<a id="GroovyLibraryInfo"></a>

## GroovyLibraryInfo

<pre>
load("@rules_groovy//groovy:defs.bzl", "GroovyLibraryInfo")

GroovyLibraryInfo(<a href="#GroovyLibraryInfo-srcs">srcs</a>)
</pre>

Groovy-specific library metadata. Companion to `JavaInfo` on every `groovy_library` target. Reserved for future `gazelle-groovy` and strict-deps tooling; consumers should not depend on the field list being stable across major versions.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="GroovyLibraryInfo-srcs"></a>srcs |  depset[File]: the .groovy and .java sources that produced this library.    |


<a id="GroovyToolchainInfo"></a>

## GroovyToolchainInfo

<pre>
load("@rules_groovy//groovy:defs.bzl", "GroovyToolchainInfo")

GroovyToolchainInfo(<a href="#GroovyToolchainInfo-groovyc">groovyc</a>, <a href="#GroovyToolchainInfo-sdk_files">sdk_files</a>, <a href="#GroovyToolchainInfo-runtime_jar">runtime_jar</a>, <a href="#GroovyToolchainInfo-version">version</a>)
</pre>

Resolved Groovy SDK + runtime info for a single toolchain instance.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="GroovyToolchainInfo-groovyc"></a>groovyc |  File: the groovyc launcher executable (script or in-process driver).    |
| <a id="GroovyToolchainInfo-sdk_files"></a>sdk_files |  depset[File]: full SDK contents for action inputs.    |
| <a id="GroovyToolchainInfo-runtime_jar"></a>runtime_jar |  File: the groovy-X.Y.Z.jar to put on the runtime classpath.    |
| <a id="GroovyToolchainInfo-version"></a>version |  string: e.g. '4.0.32'. Diagnostics only - actions read SDK files, not the version string.    |


