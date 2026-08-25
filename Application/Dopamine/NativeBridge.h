#ifndef DOPAMINE_NATIVE_BRIDGE_H
#define DOPAMINE_NATIVE_BRIDGE_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Stable C ABI consumed from Dart through dart:ffi.
extern "C" {
char *dopamine_state_json(void);
int dopamine_start_jailbreak(const char *json);
int dopamine_run_action(const char *action, const char *json);
long dopamine_read_log_line(char *buffer, long capacity);
void dopamine_free_string(char *string);
}

NS_ASSUME_NONNULL_END
#endif
