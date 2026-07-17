#include <mpv/client.h>
#include <iostream>
#include <unistd.h>

int main() {
    mpv_handle *mpv = mpv_create();
    
    mpv_set_option_string(mpv, "vo", "gpu");
    mpv_set_option_string(mpv, "hwdec", "vaapi");
    mpv_set_option_string(mpv, "msg-level", "all=v");
    
    mpv_initialize(mpv);
    
    const char *cmd[] = {"loadfile", "/home/geonix/Build/flex_player/tests/dummy1.mkv", NULL};
    mpv_command(mpv, cmd);
    
    sleep(1);
    mpv_terminate_destroy(mpv);
    return 0;
}
