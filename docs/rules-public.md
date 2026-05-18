<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public Groovy build rules.

This file defines the user-facing rules and macros — `groovy_library`,
`groovy_and_java_library`, `groovy_binary`, `groovy_test`,
`groovy_junit_test`, `groovy_junit5_test`, and `spock_test`. The
shape mirrors `rules_kotlin`'s `kt_jvm_library` — a single rule that
returns `JavaInfo` directly, accepts mixed `.groovy` + `.java` srcs
natively, and exposes the standard JVM-rule attribute surface
(`runtime_deps`, `exports`, `data`, `resources`, `neverlink`,
`plugins`).

All actions are hermetic and resolved through the toolchain registered
by the `groovy` module extension (see `extensions.bzl`).

Macro signatures preserve source-level compatibility with upstream
`bazelbuild/rules_groovy 0.0.6`; downstream BUILD files keep working
without edits.

Test rules pull JUnit / Spock / hamcrest / Jupiter / Platform artifacts
off the toolchain's `dep_providers` list (`GroovyDepsInfo.name`); the
legacy `@junit_artifact`, `@spock_artifact`, `@groovy_sdk_artifact`
literal labels no longer appear in this file (ISSUE-061).

Every wrapping macro in this file is a Bazel-8+ symbolic macro
(`macro(implementation = ..., attrs = ...)`); legacy `def`-based macros
were retired in ISSUE-067. Callers see unchanged signatures — the
migration is internal — and benefit from explicit `name`/`visibility`
parameters on each impl function plus macro-scoped visibility on every
internal scaffolding target the macro emits.

<a id="groovy_library"></a>

## groovy_library

<pre>
load("@rules_groovy//groovy:groovy.bzl", "groovy_library")

groovy_library(<a href="#groovy_library-name">name</a>, <a href="#groovy_library-deps">deps</a>, <a href="#groovy_library-srcs">srcs</a>, <a href="#groovy_library-data">data</a>, <a href="#groovy_library-resources">resources</a>, <a href="#groovy_library-exports">exports</a>, <a href="#groovy_library-neverlink">neverlink</a>, <a href="#groovy_library-plugins">plugins</a>, <a href="#groovy_library-runtime_deps">runtime_deps</a>)
</pre>

Compile Groovy (and optionally Java) sources into a JVM library jar. Returns `JavaInfo` directly; consumers may depend on this target from `java_library`, `java_binary`, `java_test`, or another `groovy_library` interchangeably.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="groovy_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="groovy_library-deps"></a>deps |  Compile- and runtime-classpath JavaInfo-providing deps.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_library-srcs"></a>srcs |  Groovy and/or Java source files. Joint-compiled by groovyc.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_library-data"></a>data |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_library-resources"></a>resources |  Resource files. v0.1 folds these into a side `java_library` via the `groovy_test` / `groovy_junit_test` macros; for a `groovy_library` consumer, attach a separate `java_library` with `resources = [...]` and list it in `deps` until the v0.2 inline-resources support lands.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_library-exports"></a>exports |  Deps re-exported to consumers of this library.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_library-neverlink"></a>neverlink |  -   | Boolean | optional |  `False`  |
| <a id="groovy_library-plugins"></a>plugins |  Java compiler plugins. Currently a no-op for Groovy; reserved.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_library-runtime_deps"></a>runtime_deps |  Runtime-only deps. Not on compile classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="groovy_runtime"></a>

## groovy_runtime

<pre>
load("@rules_groovy//groovy:groovy.bzl", "groovy_runtime")

groovy_runtime(<a href="#groovy_runtime-name">name</a>)
</pre>

Exposes the active Groovy toolchain's resolved runtime jar as a `JavaInfo`-providing target. Useful for non-`groovy_*` rules (e.g. plain `java_binary`) that need Groovy on their runtime classpath — list `@rules_groovy//groovy:runtime` in `runtime_deps`. Resolves via the active toolchain, including the per-version selection driven by the `groovy_version` build flag (PR #22), so the jar always matches the toolchain every other rule in this set is using.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="groovy_runtime-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |


<a id="path_to_class"></a>

## path_to_class

<pre>
load("@rules_groovy//groovy:groovy.bzl", "path_to_class")

path_to_class(<a href="#path_to_class-path">path</a>, <a href="#path_to_class-src_roots">src_roots</a>)
</pre>

Convert a test source path to a Java/Groovy fully-qualified class name.

Strips the longest matching prefix in `src_roots`, then drops the
`.groovy` or `.java` extension, then converts `/` to `.`.

With the default `src_roots`:

  * `src/test/groovy/<pkg>/<Cls>.groovy` → `<pkg>.<Cls>`
  * `src/test/java/<pkg>/<Cls>.java`     → `<pkg>.<Cls>`
  * `src/test/java/<pkg>/<Cls>.groovy`   → `<pkg>.<Cls>`  (Groovy under java/
                                                          is legal — groovyc
                                                          accepts mixed sources)

Custom roots — e.g. `src_roots = ["example/foo/src/test/groovy"]` —
work the same way; the longest matching root wins so nested layouts
behave sensibly.

Fails loudly when no root matches, or when the source's extension is
not `.groovy` / `.java`.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="path_to_class-path"></a>path |  Workspace-relative path to a test source file.   |  none |
| <a id="path_to_class-src_roots"></a>src_roots |  Source-root prefixes to try, longest first. Defaults to `["src/test/groovy", "src/test/java"]`.   |  `["src/test/groovy", "src/test/java"]` |


<a id="groovy_and_java_library"></a>

## groovy_and_java_library

<pre>
load("@rules_groovy//groovy:groovy.bzl", "groovy_and_java_library")

groovy_and_java_library(*, <a href="#groovy_and_java_library-name">name</a>, <a href="#groovy_and_java_library-deps">deps</a>, <a href="#groovy_and_java_library-srcs">srcs</a>, <a href="#groovy_and_java_library-data">data</a>, <a href="#groovy_and_java_library-resources">resources</a>, <a href="#groovy_and_java_library-aspect_hints">aspect_hints</a>, <a href="#groovy_and_java_library-compatible_with">compatible_with</a>,
                        <a href="#groovy_and_java_library-deprecation">deprecation</a>, <a href="#groovy_and_java_library-exec_compatible_with">exec_compatible_with</a>, <a href="#groovy_and_java_library-exec_group_compatible_with">exec_group_compatible_with</a>,
                        <a href="#groovy_and_java_library-exec_properties">exec_properties</a>, <a href="#groovy_and_java_library-exports">exports</a>, <a href="#groovy_and_java_library-features">features</a>, <a href="#groovy_and_java_library-neverlink">neverlink</a>, <a href="#groovy_and_java_library-package_metadata">package_metadata</a>, <a href="#groovy_and_java_library-plugins">plugins</a>,
                        <a href="#groovy_and_java_library-restricted_to">restricted_to</a>, <a href="#groovy_and_java_library-runtime_deps">runtime_deps</a>, <a href="#groovy_and_java_library-tags">tags</a>, <a href="#groovy_and_java_library-target_compatible_with">target_compatible_with</a>, <a href="#groovy_and_java_library-testonly">testonly</a>,
                        <a href="#groovy_and_java_library-toolchains">toolchains</a>, <a href="#groovy_and_java_library-visibility">visibility</a>)
</pre>

Deprecated alias for `groovy_library`.

`groovy_library` now accepts mixed `.groovy` and `.java` srcs natively
via joint compilation through groovyc; there is no behavioral
difference between calling `groovy_library(...)` and
`groovy_and_java_library(...)`. This alias exists only for
source-level compatibility with upstream `bazelbuild/rules_groovy
0.0.6` BUILD files.

Deprecated: use `groovy_library` directly. This alias is removed in v0.2.0.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="groovy_and_java_library-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="groovy_and_java_library-deps"></a>deps |  Compile- and runtime-classpath JavaInfo-providing deps.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_and_java_library-srcs"></a>srcs |  List of `.groovy` and/or `.java` source files.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_and_java_library-data"></a>data |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_and_java_library-resources"></a>resources |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_and_java_library-aspect_hints"></a>aspect_hints |  <a href="https://bazel.build/reference/be/common-definitions#common.aspect_hints">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_and_java_library-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_and_java_library-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_and_java_library-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_and_java_library-exec_group_compatible_with"></a>exec_group_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_group_compatible_with">Inherited rule attribute</a>   | Dictionary: String -> List of labels; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_and_java_library-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="groovy_and_java_library-exports"></a>exports |  Deps re-exported to consumers of this library.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_and_java_library-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="groovy_and_java_library-neverlink"></a>neverlink |  -   | Boolean | optional |  `False`  |
| <a id="groovy_and_java_library-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_and_java_library-plugins"></a>plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_and_java_library-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_and_java_library-runtime_deps"></a>runtime_deps |  Runtime-only deps. Not on compile classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_and_java_library-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_and_java_library-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_and_java_library-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_and_java_library-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_and_java_library-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |


<a id="groovy_binary"></a>

## groovy_binary

<pre>
load("@rules_groovy//groovy:groovy.bzl", "groovy_binary")

groovy_binary(*, <a href="#groovy_binary-name">name</a>, <a href="#groovy_binary-deps">deps</a>, <a href="#groovy_binary-srcs">srcs</a>, <a href="#groovy_binary-data">data</a>, <a href="#groovy_binary-resources">resources</a>, <a href="#groovy_binary-args">args</a>, <a href="#groovy_binary-aspect_hints">aspect_hints</a>, <a href="#groovy_binary-classpath_resources">classpath_resources</a>,
              <a href="#groovy_binary-compatible_with">compatible_with</a>, <a href="#groovy_binary-deploy_manifest_lines">deploy_manifest_lines</a>, <a href="#groovy_binary-deprecation">deprecation</a>, <a href="#groovy_binary-env">env</a>, <a href="#groovy_binary-exec_compatible_with">exec_compatible_with</a>,
              <a href="#groovy_binary-exec_group_compatible_with">exec_group_compatible_with</a>, <a href="#groovy_binary-exec_properties">exec_properties</a>, <a href="#groovy_binary-features">features</a>, <a href="#groovy_binary-jvm_flags">jvm_flags</a>, <a href="#groovy_binary-launcher">launcher</a>, <a href="#groovy_binary-main_class">main_class</a>,
              <a href="#groovy_binary-package_metadata">package_metadata</a>, <a href="#groovy_binary-restricted_to">restricted_to</a>, <a href="#groovy_binary-stamp">stamp</a>, <a href="#groovy_binary-tags">tags</a>, <a href="#groovy_binary-target_compatible_with">target_compatible_with</a>, <a href="#groovy_binary-testonly">testonly</a>,
              <a href="#groovy_binary-toolchains">toolchains</a>, <a href="#groovy_binary-use_testrunner">use_testrunner</a>, <a href="#groovy_binary-visibility">visibility</a>)
</pre>

Builds an executable Groovy application.

Analogous to `java_binary` but accepts `.groovy` (and `.java`) sources.
Produces a runnable target you can launch with `bazel run`.

NOTE: this macro composes `rules_java`'s `java_binary` rule for the
runnable wrapper. That's a deliberate, scoped coupling — re-implementing
the launcher script (Linux/Windows/coverage) is non-trivial and a v0.2
follow-up if needed. The Groovy SDK runtime jar enters the binary's
classpath via a hidden `_groovy_sdk_runtime` helper rule so this macro
no longer needs to reference `@groovy_sdk_artifact//:groovy` by literal
label.

Common `java_binary` attributes (`main_class`, `jvm_flags`, `data`,
`env`, `args`, `stamp`, `launcher`, `resources`, `classpath_resources`,
`deploy_manifest_lines`, `use_testrunner`) are exposed explicitly and
forwarded to the underlying `java_binary`. The `runtime_deps` attribute
is owned by this macro — the generated `_groovy_sdk_runtime` target
plus, when `srcs` is non-empty, an internal `name + "_lib"`
`groovy_library` for the binary's own sources are wired through it
automatically. Internal scaffolding (the SDK-runtime and library
targets) lives at macro-scope visibility, not the binary's package
public surface.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="groovy_binary-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="groovy_binary-deps"></a>deps |  Libraries on both the compile-time and runtime classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_binary-srcs"></a>srcs |  List of `.groovy` and/or `.java` source files compiled into the binary. May be empty if `deps` already provides the entry point.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_binary-data"></a>data |  Runtime data files made available via Bazel runfiles.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_binary-resources"></a>resources |  Resource files added to the binary's classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_binary-args"></a>args |  Default arguments passed to the binary when run via `bazel run`.   | List of strings | optional |  `[]`  |
| <a id="groovy_binary-aspect_hints"></a>aspect_hints |  <a href="https://bazel.build/reference/be/common-definitions#common.aspect_hints">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_binary-classpath_resources"></a>classpath_resources |  Resources placed at the root of the binary's classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_binary-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_binary-deploy_manifest_lines"></a>deploy_manifest_lines |  Lines added to the deploy jar's `META-INF/MANIFEST.MF`.   | List of strings | optional |  `[]`  |
| <a id="groovy_binary-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_binary-env"></a>env |  Environment variables set when the binary is run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="groovy_binary-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_binary-exec_group_compatible_with"></a>exec_group_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_group_compatible_with">Inherited rule attribute</a>   | Dictionary: String -> List of labels; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_binary-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="groovy_binary-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="groovy_binary-jvm_flags"></a>jvm_flags |  JVM flags embedded into the generated launcher script.   | List of strings | optional |  `[]`  |
| <a id="groovy_binary-launcher"></a>launcher |  Custom launcher binary used instead of the default JVM launcher.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="groovy_binary-main_class"></a>main_class |  Fully-qualified name of the entry-point class, or the name of a Groovy script class. See the [Groovy docs on scripts vs. classes](https://www.groovy-lang.org/structure.html#_scripts_versus_classes).   | String | optional |  `""`  |
| <a id="groovy_binary-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_binary-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_binary-stamp"></a>stamp |  Whether to encode build information into the binary (`-1` = use `--stamp`, `0` = never, `1` = always).   | Integer | optional |  `-1`  |
| <a id="groovy_binary-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_binary-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_binary-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_binary-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_binary-use_testrunner"></a>use_testrunner |  Use the JUnit test runner as the main class. Forwarded to `java_binary` verbatim.   | Boolean | optional |  `False`  |
| <a id="groovy_binary-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |


<a id="groovy_junit5_test"></a>

## groovy_junit5_test

<pre>
load("@rules_groovy//groovy:groovy.bzl", "groovy_junit5_test")

groovy_junit5_test(*, <a href="#groovy_junit5_test-name">name</a>, <a href="#groovy_junit5_test-deps">deps</a>, <a href="#groovy_junit5_test-data">data</a>, <a href="#groovy_junit5_test-resources">resources</a>, <a href="#groovy_junit5_test-aspect_hints">aspect_hints</a>, <a href="#groovy_junit5_test-compatible_with">compatible_with</a>, <a href="#groovy_junit5_test-deprecation">deprecation</a>,
                   <a href="#groovy_junit5_test-exec_compatible_with">exec_compatible_with</a>, <a href="#groovy_junit5_test-exec_group_compatible_with">exec_group_compatible_with</a>, <a href="#groovy_junit5_test-exec_properties">exec_properties</a>, <a href="#groovy_junit5_test-features">features</a>,
                   <a href="#groovy_junit5_test-groovy_srcs">groovy_srcs</a>, <a href="#groovy_junit5_test-java_srcs">java_srcs</a>, <a href="#groovy_junit5_test-jvm_flags">jvm_flags</a>, <a href="#groovy_junit5_test-package_metadata">package_metadata</a>, <a href="#groovy_junit5_test-restricted_to">restricted_to</a>, <a href="#groovy_junit5_test-size">size</a>,
                   <a href="#groovy_junit5_test-src_roots">src_roots</a>, <a href="#groovy_junit5_test-tags">tags</a>, <a href="#groovy_junit5_test-target_compatible_with">target_compatible_with</a>, <a href="#groovy_junit5_test-testonly">testonly</a>, <a href="#groovy_junit5_test-tests">tests</a>, <a href="#groovy_junit5_test-toolchains">toolchains</a>, <a href="#groovy_junit5_test-visibility">visibility</a>)
</pre>

Convenience macro for JUnit 5 (Jupiter)-driven Groovy tests.

Mirrors `groovy_junit_test`'s signature but routes the runtime
through `org.junit.platform.console.ConsoleLauncher`. Jupiter API,
Jupiter Engine, and the full Platform launcher classpath
(platform-launcher / engine / commons, opentest4j, apiguardian-api)
come off the active toolchain's `dep_providers` (logical names
`"junit_api"`, `"junit_engine"`, `"junit_platform_launcher"`, etc.).

Wiring this on top of a JUnit-4-only toolchain fails at runtime
(ConsoleLauncher isn't on the classpath). Either declare
`groovy.testing(junit = "5")` in your `MODULE.bazel`, or accept the
Groovy-4 default which auto-promotes to JUnit 5 because Spock 2.x
requires it.

The generated `name + "-groovylib"` target lives at macro-scope
visibility — callers do not reach into it directly.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="groovy_junit5_test-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="groovy_junit5_test-deps"></a>deps |  Libraries on both compile-time and runtime classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_junit5_test-data"></a>data |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_junit5_test-resources"></a>resources |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `[]`  |
| <a id="groovy_junit5_test-aspect_hints"></a>aspect_hints |  <a href="https://bazel.build/reference/be/common-definitions#common.aspect_hints">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_junit5_test-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit5_test-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit5_test-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit5_test-exec_group_compatible_with"></a>exec_group_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_group_compatible_with">Inherited rule attribute</a>   | Dictionary: String -> List of labels; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit5_test-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="groovy_junit5_test-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="groovy_junit5_test-groovy_srcs"></a>groovy_srcs |  Additional `.groovy` helper sources compiled into a supporting `groovy_library`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_junit5_test-java_srcs"></a>java_srcs |  Additional `.java` helper sources compiled into a supporting `java_library`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_junit5_test-jvm_flags"></a>jvm_flags |  -   | List of strings | optional |  `[]`  |
| <a id="groovy_junit5_test-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit5_test-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit5_test-size"></a>size |  -   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `"small"`  |
| <a id="groovy_junit5_test-src_roots"></a>src_roots |  -   | List of strings | optional |  `["src/test/groovy", "src/test/java"]`  |
| <a id="groovy_junit5_test-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit5_test-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_junit5_test-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit5_test-tests"></a>tests |  `.groovy` files that define JUnit 5 (Jupiter) test classes.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `[]`  |
| <a id="groovy_junit5_test-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_junit5_test-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |


<a id="groovy_junit_test"></a>

## groovy_junit_test

<pre>
load("@rules_groovy//groovy:groovy.bzl", "groovy_junit_test")

groovy_junit_test(*, <a href="#groovy_junit_test-name">name</a>, <a href="#groovy_junit_test-deps">deps</a>, <a href="#groovy_junit_test-data">data</a>, <a href="#groovy_junit_test-resources">resources</a>, <a href="#groovy_junit_test-aspect_hints">aspect_hints</a>, <a href="#groovy_junit_test-compatible_with">compatible_with</a>, <a href="#groovy_junit_test-deprecation">deprecation</a>,
                  <a href="#groovy_junit_test-exec_compatible_with">exec_compatible_with</a>, <a href="#groovy_junit_test-exec_group_compatible_with">exec_group_compatible_with</a>, <a href="#groovy_junit_test-exec_properties">exec_properties</a>, <a href="#groovy_junit_test-features">features</a>,
                  <a href="#groovy_junit_test-groovy_srcs">groovy_srcs</a>, <a href="#groovy_junit_test-java_srcs">java_srcs</a>, <a href="#groovy_junit_test-jvm_flags">jvm_flags</a>, <a href="#groovy_junit_test-package_metadata">package_metadata</a>, <a href="#groovy_junit_test-restricted_to">restricted_to</a>, <a href="#groovy_junit_test-size">size</a>, <a href="#groovy_junit_test-src_roots">src_roots</a>,
                  <a href="#groovy_junit_test-tags">tags</a>, <a href="#groovy_junit_test-target_compatible_with">target_compatible_with</a>, <a href="#groovy_junit_test-testonly">testonly</a>, <a href="#groovy_junit_test-tests">tests</a>, <a href="#groovy_junit_test-toolchains">toolchains</a>, <a href="#groovy_junit_test-visibility">visibility</a>)
</pre>

Convenience macro for JUnit-4-driven Groovy tests with helper sources.

Splits inputs into a test-only library + a `groovy_test` target. Use
this when your tests share helper Groovy or Java types that aren't
themselves test specifications. JUnit jars come from the active
toolchain's `dep_providers`, not a literal `@junit_artifact` label
(ISSUE-061).

`tests` are the JUnit-runnable specs; `groovy_srcs` and `java_srcs`
are compiled into supporting libraries on the test classpath. The
generated `name + "-groovylib"` target lives at macro-scope
visibility — callers do not reach into it directly.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="groovy_junit_test-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="groovy_junit_test-deps"></a>deps |  Libraries on both compile-time and runtime classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_junit_test-data"></a>data |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_junit_test-resources"></a>resources |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `[]`  |
| <a id="groovy_junit_test-aspect_hints"></a>aspect_hints |  <a href="https://bazel.build/reference/be/common-definitions#common.aspect_hints">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_junit_test-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit_test-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit_test-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit_test-exec_group_compatible_with"></a>exec_group_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_group_compatible_with">Inherited rule attribute</a>   | Dictionary: String -> List of labels; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit_test-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="groovy_junit_test-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="groovy_junit_test-groovy_srcs"></a>groovy_srcs |  Additional `.groovy` / `.java` helper sources compiled into a supporting `groovy_library`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_junit_test-java_srcs"></a>java_srcs |  Additional `.java` helper sources compiled into a supporting `java_library`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_junit_test-jvm_flags"></a>jvm_flags |  -   | List of strings | optional |  `[]`  |
| <a id="groovy_junit_test-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit_test-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit_test-size"></a>size |  -   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `"small"`  |
| <a id="groovy_junit_test-src_roots"></a>src_roots |  -   | List of strings | optional |  `["src/test/groovy", "src/test/java"]`  |
| <a id="groovy_junit_test-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit_test-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_junit_test-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_junit_test-tests"></a>tests |  `.groovy` / `.java` files that define JUnit test classes (the runnable specs).   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `[]`  |
| <a id="groovy_junit_test-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_junit_test-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |


<a id="groovy_test"></a>

## groovy_test

<pre>
load("@rules_groovy//groovy:groovy.bzl", "groovy_test")

groovy_test(*, <a href="#groovy_test-name">name</a>, <a href="#groovy_test-deps">deps</a>, <a href="#groovy_test-srcs">srcs</a>, <a href="#groovy_test-data">data</a>, <a href="#groovy_test-resources">resources</a>, <a href="#groovy_test-aspect_hints">aspect_hints</a>, <a href="#groovy_test-compatible_with">compatible_with</a>, <a href="#groovy_test-deprecation">deprecation</a>,
            <a href="#groovy_test-exec_compatible_with">exec_compatible_with</a>, <a href="#groovy_test-exec_group_compatible_with">exec_group_compatible_with</a>, <a href="#groovy_test-exec_properties">exec_properties</a>, <a href="#groovy_test-features">features</a>, <a href="#groovy_test-jvm_flags">jvm_flags</a>,
            <a href="#groovy_test-package_metadata">package_metadata</a>, <a href="#groovy_test-restricted_to">restricted_to</a>, <a href="#groovy_test-size">size</a>, <a href="#groovy_test-src_roots">src_roots</a>, <a href="#groovy_test-tags">tags</a>, <a href="#groovy_test-target_compatible_with">target_compatible_with</a>, <a href="#groovy_test-testonly">testonly</a>,
            <a href="#groovy_test-toolchains">toolchains</a>, <a href="#groovy_test-visibility">visibility</a>)
</pre>

Runs Groovy tests under the toolchain-selected JUnit runner.

Source filenames are converted to fully-qualified class names by
stripping the longest matching prefix in `src_roots`, then dropping
the `.groovy` / `.java` extension. Each derived class is passed to the
runner main class (`org.junit.runner.JUnitCore` for JUnit 4 toolchains,
`org.junit.platform.console.ConsoleLauncher` for JUnit 5 ones — the
active toolchain owns the choice) at execution time.

The default `src_roots` matches Maven-style layouts at the workspace
root (`src/test/groovy`, `src/test/java`). Override it to host tests
under arbitrary directory trees — e.g. `["example/foo/src/test/groovy"]`
— without rewriting `groovy/groovy.bzl`.

For convenience wrappers around JUnit/Spock that also handle library
splitting, see `groovy_junit_test`, `groovy_junit5_test`, and
`spock_test`.

JUnit / Spock jars land on the test classpath through the active
toolchain's `dep_providers` (logical names like `"junit_runner"`,
`"spock"`); the test rules no longer carry literal `@junit_artifact`
/ `@spock_artifact` labels (ISSUE-061).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="groovy_test-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="groovy_test-deps"></a>deps |  Libraries on both compile-time and runtime classpath. Accepts `groovy_library`, `java_library`, and `.jar` labels.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_test-srcs"></a>srcs |  List of `.groovy` / `.java` source files whose names map to JUnit test classes.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_test-data"></a>data |  Runtime data files made available via Bazel runfiles.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="groovy_test-resources"></a>resources |  Files packaged into a side `java_library` and added to the test classpath (useful for classpath-resource lookups).   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `[]`  |
| <a id="groovy_test-aspect_hints"></a>aspect_hints |  <a href="https://bazel.build/reference/be/common-definitions#common.aspect_hints">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_test-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_test-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_test-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_test-exec_group_compatible_with"></a>exec_group_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_group_compatible_with">Inherited rule attribute</a>   | Dictionary: String -> List of labels; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_test-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="groovy_test-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="groovy_test-jvm_flags"></a>jvm_flags |  Flags embedded into the generated test launcher script.   | List of strings | optional |  `[]`  |
| <a id="groovy_test-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_test-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_test-size"></a>size |  Bazel test size — `small`, `medium`, `large`, or `enormous`. Defaults to `medium`.   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `"medium"`  |
| <a id="groovy_test-src_roots"></a>src_roots |  Source-root prefixes used to derive each test's FQCN. Defaults to `["src/test/groovy", "src/test/java"]`. Longest matching root wins.   | List of strings | optional |  `["src/test/groovy", "src/test/java"]`  |
| <a id="groovy_test-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_test-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_test-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="groovy_test-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="groovy_test-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |


<a id="spock_test"></a>

## spock_test

<pre>
load("@rules_groovy//groovy:groovy.bzl", "spock_test")

spock_test(*, <a href="#spock_test-name">name</a>, <a href="#spock_test-deps">deps</a>, <a href="#spock_test-data">data</a>, <a href="#spock_test-resources">resources</a>, <a href="#spock_test-aspect_hints">aspect_hints</a>, <a href="#spock_test-compatible_with">compatible_with</a>, <a href="#spock_test-deprecation">deprecation</a>,
           <a href="#spock_test-exec_compatible_with">exec_compatible_with</a>, <a href="#spock_test-exec_group_compatible_with">exec_group_compatible_with</a>, <a href="#spock_test-exec_properties">exec_properties</a>, <a href="#spock_test-features">features</a>, <a href="#spock_test-groovy_srcs">groovy_srcs</a>,
           <a href="#spock_test-java_srcs">java_srcs</a>, <a href="#spock_test-jvm_flags">jvm_flags</a>, <a href="#spock_test-package_metadata">package_metadata</a>, <a href="#spock_test-restricted_to">restricted_to</a>, <a href="#spock_test-size">size</a>, <a href="#spock_test-specs">specs</a>, <a href="#spock_test-src_roots">src_roots</a>, <a href="#spock_test-tags">tags</a>,
           <a href="#spock_test-target_compatible_with">target_compatible_with</a>, <a href="#spock_test-testonly">testonly</a>, <a href="#spock_test-toolchains">toolchains</a>, <a href="#spock_test-visibility">visibility</a>)
</pre>

Convenience macro for Spock specifications.

Wraps `specs` in a test-only `groovy_library` and emits a
`groovy_test`. The Spock jar version is selected by the active
toolchain's Groovy major.minor — Groovy 2.5 pulls Spock 1.3 (JUnit
4 path), Groovy 3.0 / 4.0 pull Spock 2.3 (JUnit 5 Platform path).
The launcher invocation auto-routes through `JUnitCore` or
`ConsoleLauncher` based on the toolchain's resolved `runner_class`;
the macro itself stays signature-stable.

Spock and JUnit jars come off the active toolchain's `dep_providers`
(logical names `"spock"`, `"junit_runner"`, `"junit_api"`, etc.); no
literal `@junit_artifact` / `@spock_artifact` labels appear in this
file (ISSUE-061).

The generated `name + "-groovylib"` target lives at macro-scope
visibility — callers do not reach into it directly.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="spock_test-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="spock_test-deps"></a>deps |  Libraries on both compile-time and runtime classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="spock_test-data"></a>data |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="spock_test-resources"></a>resources |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `[]`  |
| <a id="spock_test-aspect_hints"></a>aspect_hints |  <a href="https://bazel.build/reference/be/common-definitions#common.aspect_hints">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="spock_test-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="spock_test-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="spock_test-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="spock_test-exec_group_compatible_with"></a>exec_group_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_group_compatible_with">Inherited rule attribute</a>   | Dictionary: String -> List of labels; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="spock_test-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="spock_test-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="spock_test-groovy_srcs"></a>groovy_srcs |  Additional `.groovy` helper sources compiled into a supporting `groovy_library`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="spock_test-java_srcs"></a>java_srcs |  Additional `.java` helper sources compiled into a supporting `java_library`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="spock_test-jvm_flags"></a>jvm_flags |  -   | List of strings | optional |  `[]`  |
| <a id="spock_test-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="spock_test-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="spock_test-size"></a>size |  -   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `"small"`  |
| <a id="spock_test-specs"></a>specs |  `.groovy` files defining Spock specifications.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `[]`  |
| <a id="spock_test-src_roots"></a>src_roots |  -   | List of strings | optional |  `["src/test/groovy", "src/test/java"]`  |
| <a id="spock_test-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="spock_test-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="spock_test-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="spock_test-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="spock_test-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |


