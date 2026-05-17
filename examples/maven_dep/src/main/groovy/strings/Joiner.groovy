package strings

import com.google.common.base.Joiner as GuavaJoiner

class Joiner {
    static String join(String separator, List<String> parts) {
        GuavaJoiner.on(separator).skipNulls().join(parts)
    }
}
