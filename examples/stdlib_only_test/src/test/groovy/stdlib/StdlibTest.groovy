package stdlib

import org.junit.jupiter.api.Test
import static org.junit.jupiter.api.Assertions.assertEquals
import static org.junit.jupiter.api.Assertions.assertTrue

class StdlibTest {

    @Test
    void groovyCollectionLiteralAndClosure() {
        // Groovy-only idioms: list literal + closure-driven iteration.
        // Would not survive being silently routed through javac.
        def numbers = [1, 2, 3]
        def sum = numbers.inject(0) { acc, n -> acc + n }
        assertEquals(6, sum)
    }

    @Test
    void gstringInterpolation() {
        def name = "world"
        def greeting = "hello, ${name}".toString()
        assertEquals("hello, world", greeting)
        assertTrue(greeting.startsWith("hello"))
    }
}
