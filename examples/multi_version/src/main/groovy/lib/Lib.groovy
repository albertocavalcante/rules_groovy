package lib

// Plain Groovy source that compiles cleanly on 2.5.x, 3.0.x, and
// 4.0.x. The example proves toolchain *selection* works end-to-end;
// it deliberately avoids language features that are version-gated.
class Lib {
    static String hello(String who) {
        "Hello, ${who}!"
    }
}
