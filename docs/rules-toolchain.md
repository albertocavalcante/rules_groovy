<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Groovy toolchain providers and rules.

Defines the toolchain shape consumed by `groovy_library`, `groovy_binary`,
`groovy_test`, and friends. Two providers and two rules:

  * `GroovyToolchainInfo` carries the resolved SDK (compiler, runtime jar,
    full SDK file set, version string).
  * `GroovyDepsInfo` names a `JavaInfo` bundle so the toolchain can point at
    test frameworks (junit, spock, hamcrest, ...) by logical name rather than
    by hard-coded attribute. Pattern lifted from `rules_scala`.
  * `groovy_toolchain` is the rule that produces `GroovyToolchainInfo` and a
    list of `GroovyDepsInfo` bundles.
  * `groovy_deps` wraps a `JavaInfo`-providing target into a `GroovyDepsInfo`
    with a logical name.

The toolchain type is declared in `groovy/BUILD` as
`@rules_groovy//groovy:toolchain_type`.

Compile / test actions read `ctx.toolchains["//groovy:toolchain_type"]` and
pull `GroovyToolchainInfo` off the `groovy_info` field; deps come off the
`deps` list and are matched by `GroovyDepsInfo.name`. This file only defines
the shape; the action wiring lives in `groovy/private/actions.bzl`.

<a id="groovy_deps"></a>

## groovy_deps

<pre>
load("@rules_groovy//groovy:toolchain.bzl", "groovy_deps")

groovy_deps(<a href="#groovy_deps-name">name</a>, <a href="#groovy_deps-dep">dep</a>, <a href="#groovy_deps-dep_name">dep_name</a>)
</pre>

Wraps a JavaInfo target into a GroovyDepsInfo with a logical name (dep_providers indirection).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="groovy_deps-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="groovy_deps-dep"></a>dep |  JavaInfo-providing target whose classpath backs this logical dep.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="groovy_deps-dep_name"></a>dep_name |  Logical name the toolchain looks up at use time (e.g. 'junit_runner', 'spock').   | String | required |  |


<a id="groovy_toolchain"></a>

## groovy_toolchain

<pre>
load("@rules_groovy//groovy:toolchain.bzl", "groovy_toolchain")

groovy_toolchain(<a href="#groovy_toolchain-name">name</a>, <a href="#groovy_toolchain-dep_providers">dep_providers</a>, <a href="#groovy_toolchain-groovyc">groovyc</a>, <a href="#groovy_toolchain-runner_class">runner_class</a>, <a href="#groovy_toolchain-runtime_jar">runtime_jar</a>, <a href="#groovy_toolchain-sdk">sdk</a>, <a href="#groovy_toolchain-version">version</a>)
</pre>

Defines a Groovy toolchain: compiler, SDK file set, runtime jar, and named dep bundles.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="groovy_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="groovy_toolchain-dep_providers"></a>dep_providers |  List of groovy_deps targets bound to this toolchain.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_toolchain-groovyc"></a>groovyc |  The groovyc launcher target (script or in-process driver). Read via ctx.executable.groovyc.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="groovy_toolchain-runner_class"></a>runner_class |  FQCN of the test runner main class. Defaults to `org.junit.runner.JUnitCore` (JUnit 4). Set to `org.junit.platform.console.ConsoleLauncher` when the toolchain is wired for JUnit 5 (Jupiter / Spock 2.x). The module extension sets this automatically from the resolved `groovy.testing(junit = ...)` flavor.   | String | optional |  `"org.junit.runner.JUnitCore"`  |
| <a id="groovy_toolchain-runtime_jar"></a>runtime_jar |  The groovy-X.Y.Z.jar to place on the runtime classpath.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="groovy_toolchain-sdk"></a>sdk |  Filegroup containing the full Groovy SDK contents.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="groovy_toolchain-version"></a>version |  Resolved SDK version string, e.g. '4.0.32'. Diagnostics only.   | String | required |  |


<a id="GroovyDepsInfo"></a>

## GroovyDepsInfo

<pre>
load("@rules_groovy//groovy:toolchain.bzl", "GroovyDepsInfo")

GroovyDepsInfo(<a href="#GroovyDepsInfo-name">name</a>, <a href="#GroovyDepsInfo-java_info">java_info</a>)
</pre>

Named bundle of JavaInfo-providing deps reachable from a toolchain (dep_providers indirection).

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="GroovyDepsInfo-name"></a>name |  string: logical name (e.g. 'junit_runner', 'spock', 'hamcrest').    |
| <a id="GroovyDepsInfo-java_info"></a>java_info |  JavaInfo: the actual dep bundle for consumers.    |


<a id="GroovyToolchainInfo"></a>

## GroovyToolchainInfo

<pre>
load("@rules_groovy//groovy:toolchain.bzl", "GroovyToolchainInfo")

GroovyToolchainInfo(<a href="#GroovyToolchainInfo-groovyc">groovyc</a>, <a href="#GroovyToolchainInfo-sdk_files">sdk_files</a>, <a href="#GroovyToolchainInfo-runtime_jar">runtime_jar</a>, <a href="#GroovyToolchainInfo-version">version</a>, <a href="#GroovyToolchainInfo-runner_class">runner_class</a>)
</pre>

Resolved Groovy SDK + runtime info for a single toolchain instance.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="GroovyToolchainInfo-groovyc"></a>groovyc |  File: the groovyc launcher executable (script or in-process driver).    |
| <a id="GroovyToolchainInfo-sdk_files"></a>sdk_files |  depset[File]: full SDK contents for action inputs.    |
| <a id="GroovyToolchainInfo-runtime_jar"></a>runtime_jar |  File: the groovy-X.Y.Z.jar to put on the runtime classpath.    |
| <a id="GroovyToolchainInfo-version"></a>version |  string: e.g. '4.0.32'. Diagnostics only - actions read SDK files, not the version string.    |
| <a id="GroovyToolchainInfo-runner_class"></a>runner_class |  string: FQCN of the test runner main class. `org.junit.runner.JUnitCore` for JUnit 4, `org.junit.platform.console.ConsoleLauncher` for JUnit 5. Consumed by `groovy_test`'s launcher template to pick the right invocation shape.    |


