#include <mpv/client.h>
#include <iostream>

int main() {
    mpv_handle *mpv = mpv_create();
    int c1 = mpv_set_option_string(mpv, "script", "");
    std::cout << "script res: " << c1 << std::endl;
    // wait, libmpv defaults load-scripts=no? No, if config=yes, it does not mean scripts are loaded.
    int c2 = mpv_set_option_string(mpv, "load-scripts", "yes");
    std::cout << "load-scripts res: " << c2 << std::endl;
    mpv_terminate_destroy(mpv);
    return 0;
}
