package lib

import org.junit.Test
import static org.junit.Assert.assertEquals
import static org.junit.Assert.assertTrue

/**
 * Smoke test for //example/src/main/groovy/lib:groovylib. This is the
 * first real `groovy_test` target in the repo (chapter 9 of v0.1.0).
 * Compile-time correctness is covered by chapter 4's hermetic-actions
 * rewrite; this target verifies execute-time correctness end-to-end on
 * the JVM.
 *
 * Layout note: this file lives at //src/test/groovy/lib (workspace-root
 * package) instead of under //example/. The current `groovy_test` rule
 * derives JUnit FQCNs from the source File's full workspace-relative
 * path, with a hard prefix of `src/test/groovy/` or `src/test/java/`.
 * Generalizing that via a `src_roots = [...]` attr is ISSUE-025
 * (Phase 2 / v0.2.0). Until that lands, this is the only layout the
 * macro accepts as-is, with no changes to `groovy/groovy.bzl`.
 *
 * The asserts deliberately use Groovy idioms (GString, list literals,
 * .every {}) that would not survive being silently routed through `javac`.
 * If `groovyc` weren't actually invoked, this file wouldn't compile.
 */
class GroovyLibTest {

    @Test
    void printGreetingWritesHelloWorldToStdout() {
        // Capture stdout: GroovyLib.printGreeting() println's the value of
        // JavaLib.GREETING. We verify the entire Groovy -> Java edge: the
        // script class lib.GroovyLib was emitted by groovyc, its static
        // method dispatched, and the cross-language reference resolved.
        def previous = System.out
        def buffer = new ByteArrayOutputStream()
        System.out = new PrintStream(buffer)
        try {
            GroovyLib.printGreeting()
        } finally {
            System.out = previous
        }

        def captured = buffer.toString().trim()
        assertEquals(JavaLib.GREETING, captured)

        // Groovy-only idioms below: GString interpolation + closure-driven
        // collection iteration. javac would reject both.
        def expected = "${JavaLib.GREETING}".toString()
        assertEquals(expected, captured)
        assertTrue([captured].every { it == JavaLib.GREETING })
    }
}
