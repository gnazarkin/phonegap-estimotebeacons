#import <Cordova/CDV.h>
#import <CoreBluetooth/CoreBluetooth.h>

#import <EstimoteSDK/EstimoteSDK.h>

@interface EstimoteBeacons : CDVPlugin

- (EstimoteBeacons *)pluginInitialize;
- (void) onReset;

@end
