<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public Groovy build rules.

This file defines the user-facing macros — `groovy_library`,
`groovy_and_java_library`, `groovy_binary`, `groovy_test`,
`groovy_junit_test`, and `spock_test` — plus the underlying rules that
implement them. All actions are hermetic and resolved through the
toolchain registered by the `groovy` module extension (see
`extensions.bzl`).

Macro signatures preserve source-level compatibility with upstream
`bazelbuild/rules_groovy 0.0.6`; downstream BUILD files keep working
without edits.

<a id="groovy_and_java_library"></a>

## groovy_and_java_library

<pre>
load("@rules_groovy//groovy:groovy.bzl", "groovy_and_java_library")

groovy_and_java_library(<a href="#groovy_and_java_library-name">name</a>, <a href="#groovy_and_java_library-srcs">srcs</a>, <a href="#groovy_and_java_library-testonly">testonly</a>, <a href="#groovy_and_java_library-deps">deps</a>, <a href="#groovy_and_java_library-kwargs">**kwargs</a>)
</pre>

Builds a mixed Groovy + Java library from a single source list.

Splits `srcs` by extension into a `java_library` (`.java` files) and a
Groovy compile (`.groovy` files), then bundles both into one
`java_import`. The Groovy side depends on the Java side, so Groovy
code may reference Java types but not vice-versa.

Use this rule when Groovy and Java sources are tightly coupled and
you don't want to maintain two BUILD targets by hand. For looser
coupling, prefer two separate targets — one `groovy_library`, one
`java_library` — with an explicit `deps` edge.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="groovy_and_java_library-name"></a>name |  A unique name for this target.   |  none |
| <a id="groovy_and_java_library-srcs"></a>srcs |  List of `.groovy` and `.java` source files.   |  `[]` |
| <a id="groovy_and_java_library-testonly"></a>testonly |  If `1`, the resulting `java_import` is testonly. Defaults to `0`.   |  `0` |
| <a id="groovy_and_java_library-deps"></a>deps |  List of libraries or raw `.jar` files on the compile-time classpath of both sub-libraries.   |  `[]` |
| <a id="groovy_and_java_library-kwargs"></a>kwargs |  Additional arguments forwarded to the wrapping `java_import`.   |  none |


<a id="groovy_binary"></a>

## groovy_binary

<pre>
load("@rules_groovy//groovy:groovy.bzl", "groovy_binary")

groovy_binary(<a href="#groovy_binary-name">name</a>, <a href="#groovy_binary-main_class">main_class</a>, <a href="#groovy_binary-srcs">srcs</a>, <a href="#groovy_binary-testonly">testonly</a>, <a href="#groovy_binary-deps">deps</a>, <a href="#groovy_binary-kwargs">**kwargs</a>)
</pre>

Builds an executable Groovy application.

Analogous to `java_binary` but accepts `.groovy` sources. Produces a
runnable target you can launch with `bazel run`. The Groovy runtime
jar resolved by the active toolchain is added to `runtime_deps`
automatically, so users don't have to depend on `@groovy_sdk_artifact`
explicitly.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="groovy_binary-name"></a>name |  A unique name for this target.   |  none |
| <a id="groovy_binary-main_class"></a>main_class |  Fully-qualified name of the entry-point class, or the name of a Groovy script class. See the [Groovy docs on scripts vs. classes](https://www.groovy-lang.org/structure.html#_scripts_versus_classes).   |  none |
| <a id="groovy_binary-srcs"></a>srcs |  List of `.groovy` source files compiled into the binary. May be empty if `deps` already provides the entry point.   |  `[]` |
| <a id="groovy_binary-testonly"></a>testonly |  If `1`, the binary is testonly. Defaults to `0`.   |  `0` |
| <a id="groovy_binary-deps"></a>deps |  Libraries on both the compile-time and runtime classpath.   |  `[]` |
| <a id="groovy_binary-kwargs"></a>kwargs |  Additional arguments forwarded to the underlying `java_binary` (e.g. `jvm_flags`, `visibility`, `data`).   |  none |


<a id="groovy_junit_test"></a>

## groovy_junit_test

<pre>
load("@rules_groovy//groovy:groovy.bzl", "groovy_junit_test")

groovy_junit_test(<a href="#groovy_junit_test-name">name</a>, <a href="#groovy_junit_test-tests">tests</a>, <a href="#groovy_junit_test-deps">deps</a>, <a href="#groovy_junit_test-groovy_srcs">groovy_srcs</a>, <a href="#groovy_junit_test-java_srcs">java_srcs</a>, <a href="#groovy_junit_test-data">data</a>, <a href="#groovy_junit_test-resources">resources</a>, <a href="#groovy_junit_test-jvm_flags">jvm_flags</a>, <a href="#groovy_junit_test-size">size</a>, <a href="#groovy_junit_test-tags">tags</a>)
</pre>

Convenience macro for JUnit-driven Groovy tests with helper sources.

Splits inputs into a test-only library + a `groovy_test` target. Use
this when your tests share helper Groovy or Java types that aren't
themselves test specifications.

`tests` are the JUnit-runnable specs; `groovy_srcs` and `java_srcs`
are compiled into supporting libraries on the test classpath.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="groovy_junit_test-name"></a>name |  A unique name for this target.   |  none |
| <a id="groovy_junit_test-tests"></a>tests |  `.groovy` files that define JUnit test classes (the runnable specs).   |  none |
| <a id="groovy_junit_test-deps"></a>deps |  Libraries on both compile-time and runtime classpath.   |  `[]` |
| <a id="groovy_junit_test-groovy_srcs"></a>groovy_srcs |  Additional `.groovy` helper sources compiled into a supporting `groovy_library`.   |  `[]` |
| <a id="groovy_junit_test-java_srcs"></a>java_srcs |  Additional `.java` helper sources compiled into a supporting `java_library`.   |  `[]` |
| <a id="groovy_junit_test-data"></a>data |  Runtime data files exposed via runfiles.   |  `[]` |
| <a id="groovy_junit_test-resources"></a>resources |  Files packaged into a side `java_library` and added to the test classpath.   |  `[]` |
| <a id="groovy_junit_test-jvm_flags"></a>jvm_flags |  Flags embedded into the generated test launcher script.   |  `[]` |
| <a id="groovy_junit_test-size"></a>size |  Bazel test size. Defaults to `small`.   |  `"small"` |
| <a id="groovy_junit_test-tags"></a>tags |  Bazel test tags.   |  `[]` |


<a id="groovy_library"></a>

## groovy_library

<pre>
load("@rules_groovy//groovy:groovy.bzl", "groovy_library")

groovy_library(<a href="#groovy_library-name">name</a>, <a href="#groovy_library-srcs">srcs</a>, <a href="#groovy_library-testonly">testonly</a>, <a href="#groovy_library-deps">deps</a>, <a href="#groovy_library-kwargs">**kwargs</a>)
</pre>

Builds a Groovy library jar.

Analogous to `java_library`, but accepts `.groovy` sources instead of
`.java`. The compiled jar is wrapped in a `java_import` so that Java
rules can depend on it transparently — `java_library`, `java_binary`,
and `java_test` all consume `groovy_library` targets via their `deps`
attribute.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="groovy_library-name"></a>name |  A unique name for this target.   |  none |
| <a id="groovy_library-srcs"></a>srcs |  List of `.groovy` source files to compile.   |  `[]` |
| <a id="groovy_library-testonly"></a>testonly |  If `1`, the resulting `java_import` is testonly; only other testonly targets may depend on it. Defaults to `0`.   |  `0` |
| <a id="groovy_library-deps"></a>deps |  List of libraries or raw `.jar` files on the compile-time classpath. Accepts `groovy_library`, `java_library`, `groovy_and_java_library`, and `.jar` labels.   |  `[]` |
| <a id="groovy_library-kwargs"></a>kwargs |  Additional arguments forwarded to the wrapping `java_import` (e.g. `visibility`, `tags`, `runtime_deps`).   |  none |


<a id="groovy_test"></a>

## groovy_test

<pre>
load("@rules_groovy//groovy:groovy.bzl", "groovy_test")

groovy_test(<a href="#groovy_test-name">name</a>, <a href="#groovy_test-deps">deps</a>, <a href="#groovy_test-srcs">srcs</a>, <a href="#groovy_test-data">data</a>, <a href="#groovy_test-resources">resources</a>, <a href="#groovy_test-jvm_flags">jvm_flags</a>, <a href="#groovy_test-size">size</a>, <a href="#groovy_test-tags">tags</a>)
</pre>

Runs Groovy tests under JUnit 4 (`JUnitCore`).

Source filenames are converted to fully-qualified class names via
`path_to_class`, which requires sources to live under
`src/test/groovy/...` or `src/test/java/...`. Each derived class is
passed to `org.junit.runner.JUnitCore` at execution time.

For convenience wrappers around JUnit/Spock that also handle library
splitting, see `groovy_junit_test` and `spock_test`.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="groovy_test-name"></a>name |  A unique name for this target.   |  none |
| <a id="groovy_test-deps"></a>deps |  Libraries on both compile-time and runtime classpath. Accepts `groovy_library`, `java_library`, `groovy_and_java_library`, and `.jar` labels.   |  `[]` |
| <a id="groovy_test-srcs"></a>srcs |  List of `.groovy` source files whose names map to JUnit test classes.   |  `[]` |
| <a id="groovy_test-data"></a>data |  Runtime data files made available via Bazel runfiles.   |  `[]` |
| <a id="groovy_test-resources"></a>resources |  Files packaged into a side `java_library` and added to the test classpath (useful for classpath-resource lookups).   |  `[]` |
| <a id="groovy_test-jvm_flags"></a>jvm_flags |  Flags embedded into the generated test launcher script.   |  `[]` |
| <a id="groovy_test-size"></a>size |  Bazel test size — `small`, `medium`, `large`, or `enormous`. Defaults to `medium`.   |  `"medium"` |
| <a id="groovy_test-tags"></a>tags |  Bazel test tags (e.g. `manual`, `requires-network`).   |  `[]` |


<a id="path_to_class"></a>

## path_to_class

<pre>
load("@rules_groovy//groovy:groovy.bzl", "path_to_class")

path_to_class(<a href="#path_to_class-path">path</a>)
</pre>

Convert a test source path to a Java/Groovy fully-qualified class name.

Accepts:
  * `src/test/groovy/<pkg>/<Cls>.groovy` → `<pkg>.<Cls>`
  * `src/test/java/<pkg>/<Cls>.java`     → `<pkg>.<Cls>`
  * `src/test/java/<pkg>/<Cls>.groovy`   → `<pkg>.<Cls>`  (Groovy under java/
                                                          is legal — groovyc
                                                          accepts mixed sources)

Fails loudly on any other layout. ISSUE-025 (v0.2) generalizes via a
`src_roots` attr.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="path_to_class-path"></a>path |  <p align="center"> - </p>   |  none |


<a id="spock_test"></a>

## spock_test

<pre>
load("@rules_groovy//groovy:groovy.bzl", "spock_test")

spock_test(<a href="#spock_test-name">name</a>, <a href="#spock_test-specs">specs</a>, <a href="#spock_test-deps">deps</a>, <a href="#spock_test-groovy_srcs">groovy_srcs</a>, <a href="#spock_test-java_srcs">java_srcs</a>, <a href="#spock_test-data">data</a>, <a href="#spock_test-resources">resources</a>, <a href="#spock_test-jvm_flags">jvm_flags</a>, <a href="#spock_test-size">size</a>, <a href="#spock_test-tags">tags</a>)
</pre>

Convenience macro for Spock specifications.

Wraps `specs` in a test-only `groovy_library` with JUnit and Spock
pinned on the classpath, then emits a `groovy_test` that runs the
Spock specs under the JUnit 4 runner. The Spock jar version is
selected by the active toolchain's Groovy major.minor — Groovy 2.5
pulls Spock for 2.5, Groovy 4.0 pulls Spock for 4.0.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="spock_test-name"></a>name |  A unique name for this target.   |  none |
| <a id="spock_test-specs"></a>specs |  `.groovy` files defining Spock specifications.   |  none |
| <a id="spock_test-deps"></a>deps |  Libraries on both compile-time and runtime classpath.   |  `[]` |
| <a id="spock_test-groovy_srcs"></a>groovy_srcs |  Additional `.groovy` helper sources compiled into a supporting `groovy_library`.   |  `[]` |
| <a id="spock_test-java_srcs"></a>java_srcs |  Additional `.java` helper sources compiled into a supporting `java_library`.   |  `[]` |
| <a id="spock_test-data"></a>data |  Runtime data files exposed via runfiles.   |  `[]` |
| <a id="spock_test-resources"></a>resources |  Files packaged into a side `java_library` and added to the test classpath.   |  `[]` |
| <a id="spock_test-jvm_flags"></a>jvm_flags |  Flags embedded into the generated test launcher script.   |  `[]` |
| <a id="spock_test-size"></a>size |  Bazel test size. Defaults to `small`.   |  `"small"` |
| <a id="spock_test-tags"></a>tags |  Bazel test tags.   |  `[]` |


