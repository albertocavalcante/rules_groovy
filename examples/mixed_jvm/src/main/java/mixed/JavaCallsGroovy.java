package mixed;

public final class JavaCallsGroovy {
    private JavaCallsGroovy() {}

    public static String invoke() {
        return Caller.callHelper();
    }
}
