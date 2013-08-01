//
//  RZLogHelper.h
//  Created by Nick Donaldson on 8/1/13.
//
//  Adapted from Bill Hollings' LogHelper header with additions:
//  - Include guard to protect against multiple inclusions
//  - Can override any of the default definitions using compile-time definitions
//     - NO NEED TO MODIFY THIS FILE!!!!!

// -------------------------------------------------------
//      Original LogHelper.h header comments, modified
// -------------------------------------------------------

/*
 * Bill Hollings, comment on iphoneincubator
 *
 * There are three levels of logging: debug, info and error, and each can be enabled independently
 * via the RZ_LOGGING_LEVEL_DEBUG, RZ_LOGGING_LEVEL_INFO, and RZ_LOGGING_LEVEL_ERROR switches below, respectively.
 * In addition, ALL logging can be enabled or disabled via the RZ_LOGGING_ENABLED switch below.
 *
 * To perform logging, use any of the following function calls in your code:
 *
 *	 RZLogDebug(fmt, ...) – will print if RZ_LOGGING_LEVEL_DEBUG is set on.
 *	 RZLogInfo(fmt, ...) – will print if RZ_LOGGING_LEVEL_INFO is set on.
 *	 RZLogError(fmt, ...) – will print if RZ_LOGGING_LEVEL_ERROR is set on.
 *
 * Each logging entry can optionally automatically include class, method and line information by
 * enabling the RZ_LOGGING_INCLUDE_CODE_LOCATION switch.
 *
 * Logging functions are implemented here via macros, so disabling logging, either entirely,
 * or at a specific level, removes the corresponding log invocations from the compiled code,
 * thus completely eliminating both the memory and CPU overhead that the logging calls would add.
 */

// Include guard
#ifndef __RZ_LOGHELPER_H__
#define __RZ_LOGHELPER_H__

// Set this switch to enable or disable ALL logging.
#ifndef RZ_LOGGING_ENABLED

    #define RZ_LOGGING_ENABLED	 1

#endif

// Set any or all of these switches to enable or disable logging at specific levels.
#ifndef RZ_LOGGING_LEVEL_DEBUG

    #ifdef DEBUG
        #define RZ_LOGGING_LEVEL_DEBUG   1
    #else
        #define RZ_LOGGING_LEVEL_DEBUG   0
    #endif

#endif

// Enable or disable info logs (enabled by default)
#ifndef RZ_LOGGING_LEVEL_INFO

    #define RZLOGGING_LEVEL_INFO    1

#endif

// Enable or disable error logs (enabled by default)
#ifndef RZ_LOGGING_LEVEL_ERROR

    #define RZ_LOGGING_LEVEL_ERROR  1

#endif

// Set this switch to set whether or not to include class, method and line information in the log entries.
#ifndef RZ_LOGGING_INCLUDE_CODE_LOCATION

    #define RZ_LOGGING_INCLUDE_CODE_LOCATION	1

#endif

// ***************** END OF USER SETTINGS ***************

#if !(defined(RZ_LOGGING_ENABLED) && RZ_LOGGING_ENABLED)
#undef RZ_LOGGING_LEVEL_DEBUG
#undef RZ_LOGGING_LEVEL_INFO
#undef RZ_LOGGING_LEVEL_ERROR
#endif

// Logging format
#define RZ_LOG_FORMAT_NO_LOCATION(fmt, lvl, ...) NSLog((@"[%@] " fmt), lvl, ##__VA_ARGS__)
#define RZ_LOG_FORMAT_WITH_LOCATION(fmt, lvl, ...) NSLog((@"%s [Line %d] [%@] " fmt), __PRETTY_FUNCTION__, __LINE__, lvl, ##__VA_ARGS__)

#if defined(RZ_LOGGING_INCLUDE_CODE_LOCATION) && RZ_LOGGING_INCLUDE_CODE_LOCATION
    #define RZ_LOG_FORMAT(fmt, lvl, ...) RZ_LOG_FORMAT_WITH_LOCATION(fmt, lvl, ##__VA_ARGS__)
#else
    #define RZ_LOG_FORMAT(fmt, lvl, ...) RZ_LOG_FORMAT_NO_LOCATION(fmt, lvl, ##__VA_ARGS__)
#endif

// Debug level logging
#if defined(RZ_LOGGING_LEVEL_DEBUG) && RZ_LOGGING_LEVEL_DEBUG
    #define RZLogDebug(fmt, ...) RZ_LOG_FORMAT(fmt, @"debug", ##__VA_ARGS__)
#else
    #define RZLogDebug(...)
#endif

// Info level logging
#if defined(RZ_LOGGING_LEVEL_INFO) && RZ_LOGGING_LEVEL_INFO
    #define RZLogInfo(fmt, ...) RZ_LOG_FORMAT(fmt, @"info", ##__VA_ARGS__)
#else
    #define RZLogInfo(...)
#endif

// Error level logging
#if defined(RZ_LOGGING_LEVEL_ERROR) && RZ_LOGGING_LEVEL_ERROR
    #define RZLogError(fmt, ...) RZ_LOG_FORMAT(fmt, @"***ERROR***", ##__VA_ARGS__)
#else
    #define RZLogError(...)
#endif

#endif // Include guard