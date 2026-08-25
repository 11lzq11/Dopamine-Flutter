#import "NativeBridge.h"
#import "DOUIManager+Bridge.h"
#import <sys/utsname.h>
#import <os/log.h>

#import "DOEnvironmentManager.h"
#import "DOPreferenceManager.h"
#import "DOUIManager.h"
#import "DOJailbreaker.h"

static NSDictionary *BridgeReadPrefs(void)
{
    DOPreferenceManager *prefs = [DOPreferenceManager sharedManager];
    NSNumber *rawJetsam = [prefs preferenceValueForKey:@"jetsamMultiplier"] ?: @6;
    double multiplier = rawJetsam.doubleValue * 2.0;

    return @{
        @"tweakInjectionEnabled": @([prefs boolPreferenceValueForKey:@"tweakInjectionEnabled" fallback:YES]),
        @"verboseLogsEnabled": @([prefs boolPreferenceValueForKey:@"verboseLogsEnabled" fallback:NO]),
        @"idownloadEnabled": @([prefs boolPreferenceValueForKey:@"idownloadEnabled" fallback:NO]),
        @"appJITEnabled": @([prefs boolPreferenceValueForKey:@"appJITEnabled" fallback:YES]),
        @"jetsamMultiplier": @(multiplier),
        @"removeJailbreakEnabled": @([prefs boolPreferenceValueForKey:@"removeJailbreakEnabled" fallback:NO]),
        @"bootlogoEnabled": @([prefs boolPreferenceValueForKey:@"bootlogoEnabled" fallback:YES]),
        @"customBootlogoEnabled": @([prefs boolPreferenceValueForKey:@"customBootlogoEnabled" fallback:NO]),
        @"theme": [prefs preferenceValueForKey:@"theme"] ?: @"default",
        @"packageManagers": [[DOUIManager sharedInstance] enabledPackageManagerKeys] ?: @[]
    };
}

static BOOL BridgeParse(const char *json, NSDictionary **outDictionary)
{
    NSData *data = json ? [NSData dataWithBytes:json length:strlen(json)] : nil;
    id value = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![value isKindOfClass:[NSDictionary class]]) return NO;
    if (outDictionary) *outDictionary = value;
    return YES;
}

static NSString *BridgeStateString(void)
{
    DOEnvironmentManager *environment = [DOEnvironmentManager sharedManager];
    struct utsname systemInformation;
    uname(&systemInformation);

    NSMutableDictionary *state = [NSMutableDictionary new];
    state[@"jailbroken"] = @(environment.isJailbroken);
    state[@"otherJailbreak"] = @(environment.isJailbrokenWithOtherJailbreak);
    state[@"supported"] = @(environment.isSupported);
    state[@"arm64e"] = @(environment.isArm64e);
    state[@"sptm"] = @(environment.isSPTM);
    state[@"bootstrapped"] = @(environment.isBootstrapped);
    state[@"jailbrokenVersion"] = environment.jailbrokenVersion ?: @"";
    state[@"version"] = environment.appVersionDisplayString ?: @"";
    state[@"supportString"] = environment.versionSupportString ?: @"";
    state[@"systemVersion"] = environment.systemVersion ?: @"";
    state[@"machine"] = @(systemInformation.machine);
    state[@"installedThroughTrollStore"] = @(environment.isInstalledThroughTrollStore);
    state[@"jailbreakHidden"] = @(environment.isJailbreakHidden);
    [state addEntriesFromDictionary:BridgeReadPrefs()];

    NSData *data = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil] ?: [NSData data];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

static int BridgeStart(NSDictionary *options)
{
    DOPreferenceManager *preferences = [DOPreferenceManager sharedManager];
    [preferences setPreferenceValue:@([options[@"removeJailbreak"] boolValue]) forKey:@"removeJailbreakEnabled"];
    [preferences setPreferenceValue:@([options[@"tweakInjection"] boolValue]) forKey:@"tweakInjectionEnabled"];
    [preferences setPreferenceValue:@([options[@"iDownload"] boolValue]) forKey:@"idownloadEnabled"];
    [preferences setPreferenceValue:@([options[@"appJit"] boolValue]) forKey:@"appJITEnabled"];
    [preferences setPreferenceValue:@([options[@"verboseLogs"] boolValue]) forKey:@"verboseLogsEnabled"];
    [preferences setPreferenceValue:@([options[@"jetsamMultiplier"] doubleValue]) forKey:@"jetsamMultiplier"];

    DOJailbreaker *jailbreaker = [DOJailbreaker new];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        BOOL didRemove = NO;
        BOOL showLogs = YES;
        [[DOUIManager sharedInstance] bridgeCaptureLog:@"Starting Jailbreak"];
        [jailbreaker runWithError:&error didRemoveJailbreak:&didRemove showLogs:&showLogs];
        [[DOUIManager sharedInstance] bridgeCaptureLog:error.localizedDescription ?: @"Jailbreak finished"];
        if (didRemove) [[DOUIManager sharedInstance] bridgeCaptureLog:@"Removed Jailbreak"];
    });

    return 0;
}

static int BridgeAction(NSString *action, NSDictionary *arguments)
{
    DOEnvironmentManager *environment = [DOEnvironmentManager sharedManager];
    DOPreferenceManager *preferences = [DOPreferenceManager sharedManager];

    if ([action isEqualToString:@"respring"]) {
        [environment respring];
    } else if ([action isEqualToString:@"userspaceReboot"]) {
        [environment rebootUserspace];
    } else if ([action isEqualToString:@"refreshApps"]) {
        [environment refreshJailbreakApps];
    } else if ([action isEqualToString:@"hideJailbreak"]) {
        [environment setJailbreakHidden:!environment.isJailbreakHidden];
    } else if ([action isEqualToString:@"reinstallPackageManagers"]) {
        [environment reinstallPackageManagers];
    } else if ([action isEqualToString:@"setPackageManagers"]) {
        NSArray *enabled = arguments[@"enabled"];
        if (![enabled isKindOfClass:[NSArray class]]) return -1;
        [preferences setPreferenceValue:enabled forKey:@"enabledPkgManagers"];
    } else if ([action isEqualToString:@"selectBootLogoImage"]) {
        // Flutter host handles image selection and writes Documents/bootlogo.png.
    } else if ([action isEqualToString:@"setPreference"]) {
        void (^setBool)(id, NSString *) = ^(id value, NSString *key) {
            if (key && [value respondsToSelector:@selector(boolValue)]) [preferences setPreferenceValue:@([value boolValue]) forKey:key];
        };
        setBool(arguments[@"tweakInjectionEnabled"], @"tweakInjectionEnabled");
        setBool(arguments[@"verboseLogsEnabled"], @"verboseLogsEnabled");
        setBool(arguments[@"idownloadEnabled"], @"idownloadEnabled");
        setBool(arguments[@"appJITEnabled"], @"appJITEnabled");
        setBool(arguments[@"removeJailbreakEnabled"], @"removeJailbreakEnabled");
        setBool(arguments[@"bootlogoEnabled"], @"bootlogoEnabled");
        setBool(arguments[@"customBootlogoEnabled"], @"customBootlogoEnabled");

        id jetsam = arguments[@"jetsamMultiplier"];
        if ([jetsam respondsToSelector:@selector(doubleValue)]) [preferences setPreferenceValue:@([jetsam doubleValue]) forKey:@"jetsamMultiplier"];

        id theme = arguments[@"theme"];
        if ([theme isKindOfClass:[NSString class]]) [preferences setPreferenceValue:theme forKey:@"theme"];

        if ([arguments objectForKey:@"enabledPkgManagers"]) [preferences setPreferenceValue:arguments[@"enabledPkgManagers"] forKey:@"enabledPkgManagers"];
        if (environment.isJailbroken) dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ [environment updateBootLogo]; });
    } else if ([action isEqualToString:@"resetSettings"]) {
        for (NSString *key in @[@"verboseLogsEnabled", @"tweakInjectionEnabled", @"enabledPkgManagers", @"selectedKernelExploit", @"selectedPACBypass", @"selectedPPLBypass", @"theme", @"customBootlogo", @"customBootlogoEnabled"]) {
            [preferences removePreferenceValueForKey:key];
        }
    } else if ([action isEqualToString:@"deleteBootstrap"]) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ [environment deleteBootstrap]; });
    } else {
        os_log_error(OS_LOG_DEFAULT, "Unknown Dopamine bridge action %{public}@", action);
        return -1;
    }

    return 0;
}

char *dopamine_state_json(void)
{
    return strdup(BridgeStateString().UTF8String ?: "");
}

int dopamine_start_jailbreak(const char *json)
{
    NSDictionary *options;
    if (!BridgeParse(json, &options)) return -1;
    @try { return BridgeStart(options); }
    @catch (NSException *exception) {
        [[DOUIManager sharedInstance] bridgeCaptureLog:exception.reason];
        return -1;
    }
}

int dopamine_run_action(const char *action, const char *json)
{
    NSDictionary *arguments;
    BridgeParse(json, &arguments);
    @try { return BridgeAction(@(action ?: ""), arguments ?: @{}); }
    @catch (NSException *exception) {
        [[DOUIManager sharedInstance] bridgeCaptureLog:exception.reason];
        return -1;
    }
}

long dopamine_read_log_line(char *buffer, long capacity)
{
    if (!buffer || capacity <= 1) return 0;

    NSArray<NSString *> *logs = _DopamineBridgePopLogs();
    if (logs.count == 0) return 0;

    NSData *data = [logs.firstObject dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    NSUInteger length = MIN(data.length, capacity - 1);
    memcpy(buffer, data.bytes, length);
    buffer[length] = 0;
    return (long)data.length;
}

void dopamine_free_string(char *string)
{
    free(string);
}
