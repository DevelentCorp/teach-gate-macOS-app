#ifndef Tun2socks_h
#define Tun2socks_h

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Platform error structure
typedef struct Tun2socksPlatformError {
    char* Code;
    char* Message;
} PlaterrorsPlatformError;

// Opaque pointers for Go-exported types
typedef void* Tun2socksTunWriter;
typedef void* Tun2socksClient;
typedef void* Tun2socksTunnel;

// Result structures
typedef struct {
    Tun2socksClient* client;
    PlaterrorsPlatformError* error;
} OutlineNewClientResult;

typedef struct {
    PlaterrorsPlatformError* tcpError;
    PlaterrorsPlatformError* udpError;
} OutlineTCPAndUDPConnectivityResult;

typedef struct {
    Tun2socksTunnel* tunnel;
    PlaterrorsPlatformError* error;
} Tun2socksConnectOutlineTunnelResult;

// Main functions exported from Go
extern Tun2socksConnectOutlineTunnelResult* Tun2socksConnectOutlineTunnel(Tun2socksTunWriter* tunWriter, Tun2socksClient* client, bool isUDPEnabled);
extern OutlineTCPAndUDPConnectivityResult* OutlineCheckTCPAndUDPConnectivity(Tun2socksClient* client);

#ifdef __cplusplus
}
#endif

#endif /* Tun2socks_h */