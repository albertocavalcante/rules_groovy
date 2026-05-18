package consumer

import dep_0.Dep0
import dep_99.Dep99

class Consumer {
    static String describe() {
        "${Dep0.marker()} -> ${Dep99.marker()}"
    }
}
