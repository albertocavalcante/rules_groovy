package strings

import org.junit.jupiter.api.Test
import static org.junit.jupiter.api.Assertions.assertEquals

class JoinerTest {

    @Test
    void joinsWithSeparatorAndSkipsNulls() {
        // Exercises both Joiner (rules_groovy + groovyc) and Guava
        // (rules_jvm_external resolved jar) at runtime.
        assertEquals("a-b-c", Joiner.join("-", ["a", null, "b", "c"]))
    }
}
