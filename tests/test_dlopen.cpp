#include <iostream>
#include <dlfcn.h>
int main() {
    void* handle = dlopen("libva-wayland.so.2", RTLD_LAZY);
    if (!handle) {
        std::cout << "dlopen failed: " << dlerror() << std::endl;
        return 1;
    }
    std::cout << "dlopen success" << std::endl;
    dlclose(handle);
    return 0;
}
