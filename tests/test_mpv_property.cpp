#include <mpv/client.h>
#include <iostream>

int main() {
    mpv_handle *mpv = mpv_create();
    mpv_initialize(mpv);
    
    double start_val = 1551.0;
    int res = mpv_set_property(mpv, "start", MPV_FORMAT_DOUBLE, &start_val);
    std::cout << "start double res: " << res << std::endl;
    
    std::string start_str = "1551.0";
    res = mpv_set_property(mpv, "start", MPV_FORMAT_STRING, &start_str);
    std::cout << "start string res: " << res << std::endl;
    
    mpv_terminate_destroy(mpv);
    return 0;
}
