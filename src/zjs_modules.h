// Copyright (c) 2016-2017, Intel Corporation.

#ifndef __zjs_modules_h__
#define __zjs_modules_h__

#ifndef ZJS_LINUX_BUILD
#include <zephyr.h>
#endif

#include "jerryscript.h"

#define NUM_SERVICE_ROUTINES 3
#define MAX_MODULE_STR_LEN 32

/**
 * Service routine function type
 *
 * @param handle        Handle that was registered
 *
 * @return              Time until next event, ZJS_TICKS_FOREVER if unknown
 */
typedef int32_t (*zjs_service_routine)(void* handle);

void zjs_modules_init();
void zjs_modules_cleanup();
void zjs_register_service_routine(void* handle, zjs_service_routine func);
int32_t zjs_service_routines(void);

#endif  // __zjs_modules_h__
