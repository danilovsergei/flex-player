#include <mpv/client.h>
#include <iostream>
#include <unistd.h>

int main() {
    mpv_handle *mpv = mpv_create();
    
    int c1 = mpv_set_option_string(mpv, "config", "yes");
    int c2 = mpv_set_option_string(mpv, "config-dir", "/home/geonix/.config/flex-player/mpv");
    
    std::cout << "config res: " << c1 << ", " << c2 << std::endl;
    mpv_terminate_destroy(mpv);
    return 0;
}
