// Simple wrapper to create a dynamic library
// This is a placeholder that will be replaced with proper Go-C bindings

#include <stdio.h>
#include <stdlib.h>

// Export a simple function to make this a valid dylib
__attribute__((visibility("default")))
int tun2socks_init(void) {
    return 0;
}

__attribute__((visibility("default")))
int tun2socks_start(void) {
    return 0;
}

__attribute__((visibility("default")))
int tun2socks_stop(void) {
    return 0;
}