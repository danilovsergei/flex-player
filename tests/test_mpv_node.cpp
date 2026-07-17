#include <mpv/client.h>
#include <iostream>
#include <string>

int main() {
    mpv_handle *mpv = mpv_create();
    mpv_initialize(mpv);
    
    mpv_node node;
    node.format = MPV_FORMAT_STRING;
    std::string start_str = "1551.0";
    node.u.string = const_cast<char*>(start_str.c_str());
    
    int res = mpv_set_property(mpv, "start", MPV_FORMAT_NODE, &node);
    std::cout << "start node res: " << res << std::endl;
    
    mpv_terminate_destroy(mpv);
    return 0;
}
