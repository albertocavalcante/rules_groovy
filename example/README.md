# Examples gallery

Self-contained references for every public rule and tag class. Each
subdir owns its `BUILD`, sources, and a short `README.md`. Five
examples ship real targets you can build and run; four are
README-only — they document `MODULE.bazel` shapes that cannot
coexist with this repo's own single `MODULE.bazel`.

## Built and tested

| Example | What it demonstrates |
|---------|----------------------|
| [`library_basic/`](library_basic/) | Single `groovy_library`, one source, no Java. |
| [`mixed_jvm/`](mixed_jvm/) | `groovy_and_java_library` plus explicit Java-calls-Groovy. |
| [`binary/`](binary/) | `groovy_binary` runnable via `bazel run`. |
| [`junit4/`](junit4/) | `groovy_junit_test` with `src_roots` for a nested layout. |
| [`spock/`](spock/) | `spock_test` with a data-driven `where:` table (build-only, tagged `manual`). |

Build all of the above: `bazel build //example/...`.
Run the test targets: `bazel test //example/...`.

## README-only (MODULE.bazel patterns)

| Example | What it demonstrates |
|---------|----------------------|
| [`override_url/`](override_url/) | Corporate-mirror `urls` override on `groovy.toolchain`. |
| [`local_sdk/`](local_sdk/) | `groovy.local_toolchain` against a vendored SDK. |
| [`multi_version/`](multi_version/) | Two `groovy.toolchain` declarations coexisting. |
| [`rules_jvm_external_interop/`](rules_jvm_external_interop/) | Opt-in `@maven`-resolved test deps via `groovy.testing(*_label = ...)`. |

## Legacy tree

The pre-existing `src/main/groovy/{app,lib}/` tree under this directory
is exercised by the chapter-9 smoke test at `//src/test/groovy/lib:GroovyLibTest`
and is preserved as-is. It demonstrates the same patterns as
`library_basic/`, `mixed_jvm/`, and `binary/` in a flatter layout.
