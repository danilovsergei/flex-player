#include <mpv/client.h>
#include <iostream>

int main() {
    mpv_handle *mpv = mpv_create();
    mpv_initialize(mpv);
    
    const char *cmd[] = {"loadfile", "dummy.mkv", "replace", "start=1551", NULL};
    int res = mpv_command(mpv, cmd);
    std::cout << "loadfile command res: " << res << std::endl;
    if (res < 0) std::cout << mpv_error_string(res) << std::endl;
    
    mpv_terminate_destroy(mpv);
    return 0;
}
