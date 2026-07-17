#include <fcntl.h>
#include <unistd.h>
#include <iostream>
#include <va/va.h>
#include <va/va_drm.h>

int main() {
    int fd = open("/dev/dri/renderD128", O_RDWR);
    if (fd < 0) {
        std::cout << "Failed to open renderD128" << std::endl;
        return 1;
    }
    VADisplay dpy = vaGetDisplayDRM(fd);
    if (!dpy) {
        std::cout << "vaGetDisplayDRM failed" << std::endl;
        return 1;
    }
    int major, minor;
    VAStatus status = vaInitialize(dpy, &major, &minor);
    std::cout << "vaInitialize status: " << status << " (VA_STATUS_SUCCESS is 0)" << std::endl;
    return 0;
}
