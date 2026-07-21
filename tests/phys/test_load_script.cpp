#include <mpv/client.h>
#include <iostream>
#include <unistd.h>

int main() {
    mpv_handle *mpv = mpv_create();
    mpv_initialize(mpv);
    
    const char *cmd[] = {"load-script", "/home/geonix/.config/flex-player/mpv/scripts/kde-hdr-toggle.lua", NULL};
    int res = mpv_command(mpv, cmd);
    std::cout << "load-script res: " << res << std::endl;
    
    mpv_terminate_destroy(mpv);
    return 0;
}
