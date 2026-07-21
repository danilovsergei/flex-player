#include <mpv/client.h>
#include <iostream>
#include <unistd.h>

int main() {
    mpv_handle *mpv = mpv_create();
    mpv_set_property_string(mpv, "vo", "null");
    mpv_set_property_string(mpv, "ao", "null");
    mpv_initialize(mpv);
    
    mpv_set_property_string(mpv, "start", "30");
    const char *cmd[] = {"loadfile", "dummy1.mkv", NULL};
    mpv_command(mpv, cmd);
    
    sleep(1); // give it time to load
    
    double pos = 0;
    mpv_get_property(mpv, "time-pos", MPV_FORMAT_DOUBLE, &pos);
    std::cout << "playback pos: " << pos << std::endl;
    
    mpv_terminate_destroy(mpv);
    return 0;
}
