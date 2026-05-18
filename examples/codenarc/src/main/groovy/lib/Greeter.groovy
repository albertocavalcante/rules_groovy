package lib

/**
 * Small clean Groovy class for CodeNarc to chew on. Intentionally
 * boring — the point of the example is the wiring (toolchain runtime
 * jar on a plain `java_binary`'s classpath via
 * `@rules_groovy//groovy:runtime`), not any particular Groovy idiom.
 */
class Greeter {
    String greet(String name) {
        return "hello, ${name}"
    }
}
