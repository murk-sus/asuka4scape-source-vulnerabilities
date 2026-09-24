#ifndef grabkernel_h
#define grabkernel_h

#include <Foundation/Foundation.h>

bool grab_kernelcache(NSString *outPath);
bool grab_kernelcache_for(NSString *osStr, NSString *build, NSString *modelIdentifier, NSString *boardConfig, NSString *outPath);

bool grab_images(NSString *outDir);
bool grab_images_for(NSString *osStr, NSString *build, NSString *modelIdentifier, NSString *boardConfig, NSString *outDir);

bool grab_kernelcache_for_build_number(NSString *build, NSString *outPath);

int grabkernel(char *downloadPath, int isResearchKernel);

#endif
