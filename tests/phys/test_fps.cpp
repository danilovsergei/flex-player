#include <mpv/client.h>
#include <iostream>

int main() {
    mpv_handle *mpv = mpv_create();
    mpv_initialize(mpv);
    int c1 = mpv_set_option_string(mpv, "display-fps", "120");
    int c2 = mpv_set_option_string(mpv, "override-display-fps", "120");
    std::cout << "res: " << c1 << ", " << c2 << std::endl;
    mpv_terminate_destroy(mpv);
    return 0;
}
