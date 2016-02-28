#import "EstimoteBeacons.h"

#pragma mark - Estimote Triggers Declarations

/*********************************************************/
/************ Estimote Triggers Declarations *************/
/*********************************************************/

#define EST_CDV_RULE_TYPE_GENERIC 1
#define EST_CDV_RULE_TYPE_NEARABLE_IDENTIFIER 2
#define EST_CDV_RULE_TYPE_NEARABLE_TYPE 3
#define EST_CDV_RULE_TYPE_IN_RANGE_OF_NEARABLE_IDENTIFIER 4
#define EST_CDV_RULE_TYPE_IN_RANGE_OF_NEARABLE_TYPE 5
#define EST_CDV_RULE_TYPE_OUTSIDE_RANGE_OF_NEARABLE_IDENTIFIER 6
#define EST_CDV_RULE_TYPE_OUTSIDE_RANGE_OF_NEARABLE_TYPE 7

// **************** Trigger object ****************

@interface ESTCDVTrigger : NSObject

@property NSString* triggerIdentifier;
@property NSString* callbackId;
@property ESTTrigger* nativeTrigger;
@property NSDictionary* nativeRules;  // ruleIdentifier -> ESTRule

@end

// **************** Generic rule ****************

@interface ESTCDVRuleGeneric : ESTRule

@property id pluginManager;
@property NSString* ruleIdentifier;
@property NSString* triggerIdentifier;

- (void) update;

@end

// **************** Nearable rule ****************

@interface ESTCDVRuleNearable : ESTNearableRule

@property id pluginManager;
@property NSString* ruleIdentifier;
@property NSString* triggerIdentifier;

- (void) updateWithNearable: (ESTNearable*)nearable;

@end

#pragma mark - Estimote Beacons Interface

/*********************************************************/
/************** Estimote Beacons Interface ***************/
/*********************************************************/

@interface EstimoteBeacons ()
<	ESTBeaconManagerDelegate,
	ESTBeaconConnectionDelegate,
	ESTNearableManagerDelegate,
	ESTTriggerManagerDelegate,
	CBCentralManagerDelegate >

/**
 * The beacon manager in the Estimote API.
 */
@property (nonatomic, strong) ESTBeaconManager* beaconManager;

/**
 * Dictionary of callback ids for startRangingBeaconsInRegion.
 * Region identifiers are used as keys.
 */
@property NSMutableDictionary* callbackIds_beaconsRanging;

/**
 * Dictionary of callback ids for startRangingBeaconsInRegion.
 * Region identifiers are used as keys.
 */
@property NSMutableDictionary* callbackIds_beaconsMonitoring;

/**
 * The nearable manager in the Estimote API.
 */
@property (nonatomic, strong) ESTNearableManager* nearableManager;

/**
 * Dictionary of callback ids for startRangingForIdentifier.
 * Nearable identifiers are used as keys.
 */
@property NSMutableDictionary* callbackIds_nearablesRangingIdentifier;

/**
 * Dictionary of callback ids for startRangingForType.
 * Nearable types are used as keys.
 */
@property NSMutableDictionary* callbackIds_nearablesRangingType;

/**
 * Dictionary of callback ids for startMonitoringForIdentifier.
 * Nearable identifiers are used as keys.
 */
@property NSMutableDictionary* callbackIds_nearablesMonitoringIdentifier;

/**
 * Dictionary of callback ids for startMonitoringForType.
 * Nearable types are used as keys.
 */
@property NSMutableDictionary* callbackIds_nearablesMonitoringType;

/**
 * The trigger manager in the Estimote API.
 */
@property (nonatomic, strong) ESTTriggerManager* triggerManager;

/**
 * Dictionary of trigger holder objects.
 * Trigger identifiers are used as keys.
 */
@property NSMutableDictionary* triggers;

/**
 * Bluetooth manager.
 */
@property CBCentralManager* bluetoothManager;

/**
 * Variable that tracks Bluetooth state.
 */
@property bool bluetoothState;

/**
 * Beacon Connection
 */

@property (nonatomic, strong) ESTBeaconConnection* beaconConnection;

/**
 * Beacon Connection Callback
 */

@property (nonatomic, strong) NSString* callbackIds_beaconConnection;

@end


#pragma mark - Estimote Beacons Implementation

@implementation EstimoteBeacons

/*********************************************************/
/****************** Initialise/Reset *********************/
/*********************************************************/


#pragma mark - Initialization

- (EstimoteBeacons*)pluginInitialize
{
	[self beacons_pluginInitialize];
	[self nearables_pluginInitialize];
	[self triggers_pluginInitialize];
	[self bluetooth_pluginInitialize];

	return self;
}

/**
 * From interface CDVPlugin.
 * Called when the WebView navigates or refreshes.
 */
- (void) onReset
{
	[self beacons_onReset];
	[self nearables_onReset];
	[self triggers_onReset];
	[self bluetooth_onReset];
}

- (NSDictionary *) dictionaryWithConnection:(ESTBeaconConnection *)connection
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (connection.identifier) dict[@"identifier"] = connection.identifier;
    if (connection.identifier) dict[@"macAddress"] = connection.macAddress;
    if (connection.identifier) dict[@"proximityUUID"] = connection.proximityUUID.UUIDString;
    if (connection.identifier) dict[@"major"] = connection.major;
    if (connection.identifier) dict[@"minor"] = connection.minor;
    return dict;
}

/*********************************************************/
/************ Estimote Beacons Implementation ************/
/*********************************************************/

- (void) beacons_pluginInitialize
{
	//NSLog(@"OBJC EstimoteBeacons pluginInitialize");

	// Crete beacon manager instance.
	self.beaconManager = [ESTBeaconManager new];
	self.beaconManager.delegate = self;

	// This will skip beacons with proximity CLProximityUnknown when ranging.
	self.beaconManager.avoidUnknownStateBeacons = YES;

	// Variables that track callback ids.
	self.callbackIds_beaconsRanging = [NSMutableDictionary new];
	self.callbackIds_beaconsMonitoring = [NSMutableDictionary new];
}

- (void) beacons_onReset
{
	// Reset callback variables.
	self.callbackIds_beaconsRanging = [NSMutableDictionary new];
	self.callbackIds_beaconsMonitoring = [NSMutableDictionary new];

	// TODO: Stop any ongoing ranging or monitoring.
}

#pragma mark - Helper methods

/**
 * Create a region object from a dictionary.
 * Don't worry, the curly placement is just a joke ;-)
 */
- (CLBeaconRegion *)createRegionFromDictionary:(NSDictionary*)regionDict {
	// Default values for the region object.
	NSUUID* uuid;
	NSString* identifier = @"EstimoteSampleRegion";
	CLBeaconMajorValue major = 0;
	CLBeaconMinorValue minor = 0;
	BOOL majorIsDefined = NO;
	BOOL minorIsDefined = NO;
  CLBeaconRegion *beaconRegion = [CLBeaconRegion alloc];

	// Get region values.
	for (id key in regionDict) {
		NSString* value = regionDict[key];

		if ([key isEqualToString:@"uuid"]) {
			uuid = [[NSUUID alloc] initWithUUIDString: value];
    } else if ([key isEqualToString:@"identifier"]) {
			identifier = value;
    } else if ([key isEqualToString:@"major"]) {
			major = [value integerValue];
			majorIsDefined = YES;
    } else if ([key isEqualToString:@"minor"]) {
			minor = [value integerValue];
			minorIsDefined = YES;
    }
  }

  if (uuid == (id)[NSNull null]) {
    uuid = ESTIMOTE_PROXIMITY_UUID;
  }

	// Create a beacon region object.
	if (majorIsDefined && minorIsDefined) {
		beaconRegion = [beaconRegion
      initWithProximityUUID: uuid
			major: major
			minor: minor
			identifier: identifier];
  } else if (majorIsDefined) {
		beaconRegion = [beaconRegion
			initWithProximityUUID: uuid
			major: major
			identifier:identifier];
  } else {
		beaconRegion = [beaconRegion
			initWithProximityUUID: uuid
			identifier: identifier];
  }

  return beaconRegion;
}

/**
 * Create a dictionary object from a region.
 */
- (NSDictionary *)regionToDictionary:(CLBeaconRegion *)region
{
	NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:4];

	[dict setValue:region.proximityUUID.UUIDString forKey:@"uuid"];
	[dict setValue:region.identifier forKey:@"identifier"];
	[dict setValue:region.major forKey:@"major"];
	[dict setValue:region.minor forKey:@"minor"];

	return dict;
}

/**
 * Create a dictionary key for a region.
 */
- (NSString*) regionDictionaryKey:(CLBeaconRegion*)region
{
	NSString* uuid = region.proximityUUID.UUIDString;
	int major = nil != region.major ? [region.major intValue] : 0;
	int minor = nil != region.minor ? [region.minor intValue] : 0;

	return [NSString stringWithFormat: @"%@-%i-%i", uuid, major, minor];
}

/**
 * Create a dictionary from a beacon object (used to
 * pass beacon data back to JavaScript).
 */
- (NSDictionary*) beaconToDictionary:(CLBeacon *)beacon
{
	NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:32];

	// Properties always available.
	[dict setValue:beacon.major forKey:@"major"];
	[dict setValue:beacon.minor forKey:@"minor"];
	[dict setValue:[NSNumber numberWithInteger:beacon.rssi] forKey:@"rssi"];

	// Properties available after CoreLocation based scan.
	[dict setValue:beacon.proximityUUID.UUIDString forKey:@"proximityUUID"]; // TODO: Check nil value?
  [dict setValue:[NSNumber numberWithDouble:beacon.accuracy] forKey:@"accuracy"];
	[dict setValue:[NSNumber numberWithInt:beacon.proximity] forKey:@"proximity"];


	return dict;
}

/**
 * Create a dictionary object from a region.
 */
- (NSDictionary *)dictionaryWithRegion:(CLBeaconRegion*)region
	andBeacons:(NSArray*)beacons
{
	// Convert beacons to a an array of property-value objects.
	NSMutableArray *beaconArray = [NSMutableArray array];
	for (CLBeacon *beacon in beacons)
	{
		[beaconArray addObject:[self beaconToDictionary:beacon]];
	}

	NSDictionary *regionDictionary = [self regionToDictionary:region];

	return @{
		@"region" : regionDictionary,
		@"beacons" : beaconArray
		};
}

#pragma mark - CoreLocation ranging

/**
 * Start CoreLocation ranging.
 */
- (void) beacons_startRangingBeaconsInRegion:(CDVInvokedUrlCommand*)command
{
	//NSLog(@"OBJC startRangingBeaconsInRegion");

	// Get region dictionary passed from JavaScript and
	// create a beacon region object.
	NSDictionary* regionDictionary = [command argumentAtIndex:0];
	CLBeaconRegion* region = [self createRegionFromDictionary:regionDictionary];

	// Stop any ongoing ranging for the given region.
	[self helper_stopRangingBeaconsInRegion:region];

	// Save callback id for the region.
	[self.callbackIds_beaconsRanging
		setObject:command.callbackId
		forKey:[self regionDictionaryKey:region]];

	// Start ranging.
	[self.beaconManager startRangingBeaconsInRegion:region];
}

/**
 * Stop CoreLocation ranging.
 */
- (void) beacons_stopRangingBeaconsInRegion:(CDVInvokedUrlCommand*)command
{
	// Get region dictionary passed from JavaScript and
	// create a beacon region object.
	NSDictionary* regionDictionary = [command argumentAtIndex:0];
	CLBeaconRegion* region = [self createRegionFromDictionary:regionDictionary];

	// Stop ranging.
	[self helper_stopRangingBeaconsInRegion:region];

	// Respond to JavaScript with OK.
	[self.commandDelegate
		sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
		callbackId:command.callbackId];
}

- (void) beacons_connectToBeacon: (CDVInvokedUrlCommand*)command
{
    NSDictionary *beacon = [command argumentAtIndex: 0];
    NSString* uuidString = beacon[@"uuid"];
    NSInteger major = [beacon[@"major"] integerValue];
    NSInteger minor = [beacon[@"minor"] integerValue];

    NSString *cid = [NSString stringWithFormat:@"%@:%lu:%lu", uuidString, major, minor];

    if (!self.beaconConnection) {
        NSLog(@"%s Connecting to beacon %@", __PRETTY_FUNCTION__, cid);
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
        ESTBeaconConnection *connection = [ESTBeaconConnection connectionWithProximityUUID:uuid major:major minor:minor delegate:self];
        self.beaconConnection = connection;
        self.callbackIds_beaconConnection = command.callbackId;
        [connection startConnection];
    }
    else {
        //ESTBeaconConnection *connection = self.beaconConnection;
        //if (connection.connectionStatus !== ESTConnectionStatusConnecting)
        //NSLog(@"%s Connection to %@ already in the connection pool", __PRETTY_FUNCTION__, cid);
    }
}

- (void)beaconConnectionDidSucceed:(ESTBeaconConnection *)connection
{
    NSLog(@"%s %@", __PRETTY_FUNCTION__, connection.identifier);
    NSString *callbackId = self.callbackIds_beaconConnection;
    CDVPluginResult *result;
    if (callbackId) {
        NSDictionary *message = [self dictionaryWithConnection:connection];
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        [result setKeepCallbackAsBool:YES];
    }
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

- (void)beaconConnection:(ESTBeaconConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, connection.identifier, error.localizedDescription);
    NSString *callbackId = self.callbackIds_beaconConnection;

    NSDictionary *message = @{@"connection":[self dictionaryWithConnection:connection],
                              @"code":@(error.code),
                              @"type":@"failed",
                              @"error":error.localizedDescription};
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];

    connection.delegate = nil;
    self.beaconConnection = nil;
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

- (void) beacons_writeConnectedMajor:(CDVInvokedUrlCommand*)command
{
    NSInteger major = [[command argumentAtIndex: 0] integerValue];
    if(!self.beaconConnection) {
      NSLog(@"error connecting");
    }
    ESTBeaconConnection *connection = self.beaconConnection;
    [connection writeMajor:major completion:^(unsigned short value, NSError * _Nullable error) {
      NSString *callbackId = command.callbackId;
      CDVPluginResult *result;
      if(error) {
          // NSLog(@"error writing major: %@", [error localizedDescription]);
          NSDictionary *message = @{@"code":@(error.code),
                                    @"type":@"failed",
                                    @"error":error.localizedDescription};
          result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];
          [self.commandDelegate sendPluginResult:result callbackId:callbackId];
      } else {
          // NSLog(@"beacon major value changed");
          if (callbackId) {
              NSDictionary *message = @{@"result":@"success"};
              result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
              [result setKeepCallbackAsBool:YES];
          }
      }
      [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }];
}

- (void) beacons_writeConnectedMinor:(CDVInvokedUrlCommand*)command
{
    NSInteger minor = [[command argumentAtIndex: 0] integerValue];
    if(!self.beaconConnection) {
        NSLog(@"error connecting");
    }
    ESTBeaconConnection *connection = self.beaconConnection;
    [connection writeMinor:minor completion:^(unsigned short value, NSError * _Nullable error) {
        NSString *callbackId = command.callbackId;
        CDVPluginResult *result;
        if(error) {
            // NSLog(@"error writing minor: %@", [error localizedDescription]);
            NSDictionary *message = @{@"code":@(error.code),
                                      @"type":@"failed",
                                      @"error":error.localizedDescription};
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        } else {
            // NSLog(@"beacon minor value changed");
            if (callbackId) {
                NSDictionary *message = @{@"result":@"success"};
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
                [result setKeepCallbackAsBool:YES];
            }
        }
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }];
}

- (void) beacons_writeConnectedProximityUUID:(CDVInvokedUrlCommand*)command
{
    NSLog(@"writeConnectedBeaconUUID called");
}

- (void) beacons_disconnectConnectedBeacon:(CDVInvokedUrlCommand*)command
{
    if(self.beaconConnection) {
        // NSLog(@"Disconnecting from beacon");
        [self.beaconConnection disconnect];
        NSString *callbackId = command.callbackId;
        NSDictionary *message = @{@"result":@"Successfull disconnect"};
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void)beaconConnection:(ESTBeaconConnection *)connection didDisconnectWithError:(NSError * _Nullable)error
{
    if(error) {
        NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, connection.identifier, error);
				NSString *callbackId = self.callbackIds_beaconConnection;
        NSDictionary *message = @{@"connection":[self dictionaryWithConnection:connection],
                                  @"code":@(error.code),
                                  @"type":@"disconnected",
                                  @"error":error.localizedDescription};
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];

        connection.delegate = nil;
        self.beaconConnection = nil;
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}


- (void) helper_stopRangingBeaconsInRegion:(CLBeaconRegion*)region
{
	// Stop ranging the region.
	[self.beaconManager stopRangingBeaconsInRegion:region];

	// Clear any existing callback.
	NSString* callbackId = [self.callbackIds_beaconsRanging
		objectForKey:[self regionDictionaryKey:region]];
	if (nil != callbackId)
	{
		// Clear callback on the JS side.
		CDVPluginResult* result = [CDVPluginResult
			resultWithStatus:CDVCommandStatus_NO_RESULT];
		[result setKeepCallbackAsBool:NO];
		[self.commandDelegate
			sendPluginResult:result
			callbackId:callbackId];

		// Clear callback id.
		[self.callbackIds_beaconsRanging
			removeObjectForKey:[self regionDictionaryKey:region]];
	}
}

/**
 * CoreLocation ranging event.
 */
- (void) beaconManager:(ESTBeaconManager*)manager
	didRangeBeacons:(NSArray*)beacons
	inRegion:(CLBeaconRegion*)region
{
	if ([beacons count] > 0)
	{
		NSString* callbackId = [self.callbackIds_beaconsRanging
			objectForKey:[self regionDictionaryKey:region]];
		if (nil != callbackId)
		{
			// Create dictionary with result.
			NSDictionary* resultDictionary = [self
				dictionaryWithRegion:region
				andBeacons:beacons];

			// Pass result to JavaScript callback.
			CDVPluginResult* result = [CDVPluginResult
				resultWithStatus:CDVCommandStatus_OK
				messageAsDictionary:resultDictionary];
			[result setKeepCallbackAsBool: YES];
			[self.commandDelegate
				sendPluginResult:result
				callbackId:callbackId];
		}
	}
}

/**
 * CoreLocation ranging error event.
 */
- (void) beaconManager:(ESTBeaconManager*)manager
	rangingBeaconsDidFailForRegion:(CLBeaconRegion*)region
	withError:(NSError*)error
{
	// Send error message before callback is cleared.
	NSString* callbackId = [self.callbackIds_beaconsRanging
		objectForKey:[self regionDictionaryKey:region]];
	if (nil != callbackId)
	{
		// Pass error to JavaScript.
		[self.commandDelegate
			sendPluginResult:[CDVPluginResult
				resultWithStatus:CDVCommandStatus_ERROR
				messageAsString: error.localizedDescription]
			callbackId: callbackId];
	}

	// Stop ranging and clear callback.
	[self helper_stopRangingBeaconsInRegion:region];
}

#pragma mark - CoreLocation monitoring

/**
 * Start CoreLocation monitoring.
 */
- (void) beacons_startMonitoringForRegion:(CDVInvokedUrlCommand*)command
{
	//NSLog(@"OBJC startMonitoringForRegion");

	// Get region dictionary passed from JavaScript and
	// create a beacon region object.
	NSDictionary* regionDictionary = [command argumentAtIndex:0];
	CLBeaconRegion* region = [self createRegionFromDictionary:regionDictionary];

	// Set region notification when display is activated.
	region.notifyEntryStateOnDisplay = (BOOL)[command argumentAtIndex:1];

	// Stop any ongoing monitoring for the given region.
	[self helper_stopMonitoringForRegion:region];

	// Save callback id for the region.
	[self.callbackIds_beaconsMonitoring
		setObject:command.callbackId
		forKey:[self regionDictionaryKey:region]];

	// Start monitoring.
	[self.beaconManager startMonitoringForRegion:region];

	// This will get the initial state faster.
	[self.beaconManager requestStateForRegion:region];
}

/**
 * Stop CoreLocation monitoring.
 */
- (void) beacons_stopMonitoringForRegion:(CDVInvokedUrlCommand*)command
{
	// Get region dictionary passed from JavaScript and
	// create a beacon region object.
	NSDictionary* regionDictionary = [command argumentAtIndex:0];
	CLBeaconRegion* region = [self createRegionFromDictionary:regionDictionary];

	// Stop monitoring.
	[self helper_stopMonitoringForRegion:region];

	// Respond to JavaScript with OK.
	[self.commandDelegate
		sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
		callbackId:command.callbackId];
}

- (void) helper_stopMonitoringForRegion:(CLBeaconRegion*)region
{
	// Stop monitoring the region.
	[self.beaconManager stopMonitoringForRegion:region];

	// Clear any existing callback.
	NSString* callbackId = [self.callbackIds_beaconsMonitoring
		objectForKey:[self regionDictionaryKey:region]];
	if (nil != callbackId)
	{
		// Clear callback on the JS side.
		CDVPluginResult* result = [CDVPluginResult
			resultWithStatus:CDVCommandStatus_NO_RESULT];
		[result setKeepCallbackAsBool:NO];
		[self.commandDelegate
			sendPluginResult:result
			callbackId:callbackId];

		// Clear callback id.
		[self.callbackIds_beaconsMonitoring
			removeObjectForKey:[self regionDictionaryKey:region]];
	}
}

- (void) beaconManager:(ESTBeaconManager *)manager
	didStartMonitoringForRegion:(CLBeaconRegion *)region
{
	// Not used.
}

- (void) beaconManager:(ESTBeaconManager *)manager
	didEnterRegion:(CLBeaconRegion *)region
{
	// Not used.
}

- (void) beaconManager:(ESTBeaconManager *)manager
	didExitRegion:(CLBeaconRegion *)region
{
	// Not used.
}

/**
 * CoreLocation monitoring event.
 */
- (void) beaconManager:(ESTBeaconManager *)manager
	didDetermineState:(CLRegionState)state
	forRegion:(CLBeaconRegion *)region
{
	//NSLog(@"OBJC didDetermineStateforRegion");

	// Send result to JavaScript.
	NSString* callbackId = [self.callbackIds_beaconsMonitoring
		objectForKey:[self regionDictionaryKey:region]];
	if (nil != callbackId)
	{
		// Create state string.
		NSString* stateString;
		switch (state)
		{
			case CLRegionStateInside:
				stateString = @"inside";
				break;
			case CLRegionStateOutside:
				stateString = @"outside";
				break;
			case CLRegionStateUnknown:
			default:
				stateString = @"unknown";
		}

		// Create result object.
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:8];
		[dict setValue:region.proximityUUID.UUIDString forKey:@"uuid"];
		[dict setValue:region.identifier forKey:@"identifier"];
		[dict setValue:region.major forKey:@"major"];
		[dict setValue:region.minor forKey:@"minor"];
		[dict setValue:stateString forKey:@"state"];

		// Send result.
		CDVPluginResult* result = [CDVPluginResult
			resultWithStatus:CDVCommandStatus_OK
			messageAsDictionary:dict];
		[result setKeepCallback:[NSNumber numberWithBool:YES]];
		[self.commandDelegate sendPluginResult:result callbackId:callbackId];
	}
}

/**
 * CoreLocation monitoring error event.
 */
- (void) beaconManager:(ESTBeaconManager *)manager
	monitoringDidFailForRegion:(CLBeaconRegion *)region
	withError:(NSError *)error
{
	// Send error message before callback is cleared.
	NSString* callbackId = [self.callbackIds_beaconsMonitoring
		objectForKey:[self regionDictionaryKey:region]];
	if (nil != callbackId)
	{
		// Pass error to JavaScript.
		[self.commandDelegate
			sendPluginResult:[CDVPluginResult
				resultWithStatus:CDVCommandStatus_ERROR
				messageAsString: error.localizedDescription]
			callbackId: callbackId];
	}

	// Stop monitoring and clear callback.
	[self helper_stopMonitoringForRegion:region];
}

#pragma mark - CoreLocation authorization

/**
 * Request authorisation for use when app is in foreground.
 */
- (void) beacons_requestWhenInUseAuthorization:(CDVInvokedUrlCommand*)command
{
	//NSLog(@"OBJC requestWhenInUseAuthorization");

    // Only applicable on iOS 8 and above.
    if (IsAtLeastiOSVersion(@"8.0"))
	{
		[self.beaconManager requestWhenInUseAuthorization];
	}

	// Return OK to JavaScript.
	[self.commandDelegate
		sendPluginResult:[CDVPluginResult
			resultWithStatus:CDVCommandStatus_OK]
		callbackId:command.callbackId];
}

/**
 * Request authorisation for use also when app is in background.
 */
- (void) beacons_requestAlwaysAuthorization:(CDVInvokedUrlCommand*)command
{
	//NSLog(@"OBJC requestAlwaysAuthorization");

    // Only applicable on iOS 8 and above.
    if (IsAtLeastiOSVersion(@"8.0"))
	{
		[self.beaconManager requestAlwaysAuthorization];
	}

	// Return OK to JavaScript.
	[self.commandDelegate
		sendPluginResult:[CDVPluginResult
			resultWithStatus:CDVCommandStatus_OK]
		callbackId:command.callbackId];
}

/**
 * Get authorisation status.
 */
- (void) beacons_authorizationStatus:(CDVInvokedUrlCommand*)command
{
	//NSLog(@"OBJC authorizationStatus");

	// Default value.
	// TODO: Should we use the real value also on iOS 7? Is it available?
	CLAuthorizationStatus status = kCLAuthorizationStatusNotDetermined;

    // Only available on iOS 8 and above.
    if (IsAtLeastiOSVersion(@"8.0"))
	{
		status = [ESTBeaconManager authorizationStatus];
	}

	// Return status value to JavaScript.
	[self.commandDelegate
		sendPluginResult:[CDVPluginResult
			resultWithStatus:CDVCommandStatus_OK
			messageAsInt:status]
		callbackId:command.callbackId];
}

#pragma mark - Config methods

- (void) beacons_enableMonitoringAnalytics: (CDVInvokedUrlCommand*)command
{
	BOOL enable = [[command argumentAtIndex: 0] boolValue];

	[ESTConfig enableMonitoringAnalytics: enable];

	[self.commandDelegate
		sendPluginResult: [CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
		callbackId: command.callbackId];
}

- (void) beacons_enableRangingAnalytics: (CDVInvokedUrlCommand*)command
{
	BOOL enable = [[command argumentAtIndex: 0] boolValue];

	[ESTConfig enableRangingAnalytics: enable];

	[self.commandDelegate
		sendPluginResult: [CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
		callbackId: command.callbackId];
}

- (void) beacons_isMonitoringAnalyticsEnabled: (CDVInvokedUrlCommand*)command
{
	BOOL isAnalyticsEnabled = [ESTConfig isMonitoringAnalyticsEnabled];

	[self.commandDelegate
		sendPluginResult: [CDVPluginResult
			resultWithStatus: CDVCommandStatus_OK
			messageAsBool: isAnalyticsEnabled]
		callbackId: command.callbackId];
}

- (void) beacons_isRangingAnalyticsEnabled: (CDVInvokedUrlCommand*)command
{
	BOOL isAnalyticsEnabled = [ESTConfig isRangingAnalyticsEnabled];

	[self.commandDelegate
		sendPluginResult: [CDVPluginResult
			resultWithStatus: CDVCommandStatus_OK
			messageAsBool: isAnalyticsEnabled]
		callbackId: command.callbackId];
}

- (void) beacons_isAuthorized: (CDVInvokedUrlCommand*)command
{
	BOOL isAuthorized = [ESTConfig isAuthorized];

	[self.commandDelegate
		sendPluginResult: [CDVPluginResult
			resultWithStatus: CDVCommandStatus_OK
			messageAsBool: isAuthorized]
		callbackId: command.callbackId];
}

- (void) beacons_setupAppIDAndAppToken: (CDVInvokedUrlCommand*)command
{
	NSString* appID = [command argumentAtIndex: 0];
	NSString* appToken = [command argumentAtIndex: 1];

	[ESTConfig setupAppID: appID andAppToken: appToken];

	[self.commandDelegate
		sendPluginResult: [CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
		callbackId: command.callbackId];
}

#pragma mark - Virtual Beacon methods

// A virtual beacon is an iPhone that pretends to be an iBeacon.

- (void) beacons_startAdvertisingAsBeacon: (CDVInvokedUrlCommand*)command
{
	NSString* uuidString = [command argumentAtIndex: 0];
	NSInteger major = [[command argumentAtIndex: 1] intValue];
	NSInteger minor = [[command argumentAtIndex: 2] intValue];
	NSString* regionId = [command argumentAtIndex: 3];
	NSUUID* uuid = [[NSUUID alloc] initWithUUIDString: uuidString];

	if (nil == uuid)
	{
		[self.commandDelegate
			sendPluginResult: [CDVPluginResult
				resultWithStatus: CDVCommandStatus_ERROR
				messageAsString: @"Invalid UUID"]
			callbackId: command.callbackId];
		return;
	}

	[self.beaconManager
		startAdvertisingWithProximityUUID: uuid
		major: major
		minor: minor
		identifier: regionId];

	[self.commandDelegate
		sendPluginResult: [CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
		callbackId: command.callbackId];
}

- (void) beacons_stopAdvertisingAsBeacon: (CDVInvokedUrlCommand*)command
{
	NSLog(@"beacons_stopAdvertisingAsBeacon");

	[self.beaconManager stopAdvertising];

	[self.commandDelegate
		sendPluginResult: [CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
		callbackId: command.callbackId];
}

#pragma mark - Estimote Nearbles Implementation

/*********************************************************/
/************ Estimote Nearbles Implementation ***********/
/*********************************************************/

#pragma mark - Initialization

- (void) nearables_pluginInitialize
{
	//NSLog(@"OBJC EstimoteNearables pluginInitialize");

	// Crete Nearable manager instance.
	self.nearableManager = [ESTNearableManager new];
	self.nearableManager.delegate = self;

	// Variables that track callbacks.
	self.callbackIds_nearablesRangingIdentifier = [NSMutableDictionary new];
	self.callbackIds_nearablesRangingType = [NSMutableDictionary new];
	self.callbackIds_nearablesMonitoringIdentifier = [NSMutableDictionary new];
	self.callbackIds_nearablesMonitoringType = [NSMutableDictionary new];
}

/**
 * From interface CDVPlugin.
 * Called when the WebView navigates or refreshes.
 */
- (void) nearables_onReset
{
	// Reset callback variables.
	self.callbackIds_nearablesRangingIdentifier = [NSMutableDictionary new];
	self.callbackIds_nearablesRangingType = [NSMutableDictionary new];
	self.callbackIds_nearablesMonitoringIdentifier = [NSMutableDictionary new];
	self.callbackIds_nearablesMonitoringType = [NSMutableDictionary new];

	// Stop any ongoing ranging/monitoring.
	[self.nearableManager stopRanging];
	[self.nearableManager stopMonitoring];
}

#pragma mark - Nearables helper methods

/**
 * Create a dictionary from a Nearable object (used to
 * pass data back to JavaScript).
 */
- (NSDictionary*) nearableToDictionary: (ESTNearable*)nearable
{
	NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:32];

	[dict setValue: [NSNumber numberWithInt: nearable.type]
		forKey: @"type"];
	[dict setValue: [ESTNearableDefinitions nameForType: nearable.type]
		forKey: @"nameForType"];
	[dict setValue: [NSNumber numberWithInt: nearable.type]
		forKey: @"color"];
	[dict setValue: nearable.identifier
		forKey: @"identifier"];
	[dict setValue: nearable.hardwareVersion
		forKey: @"hardwareVersion"];
	[dict setValue: nearable.firmwareVersion
		forKey: @"firmwareVersion"];
	[dict setValue: [NSNumber numberWithInteger: nearable.rssi]
		forKey: @"rssi"];
	[dict setValue: [NSNumber numberWithInt: nearable.zone]
		forKey: @"zone"];
	[dict setValue: nearable.idleBatteryVoltage
		forKey: @"idleBatteryVoltage"];
	[dict setValue: nearable.stressBatteryVoltage
		forKey: @"stressBatteryVoltage"];
	[dict setValue: [NSNumber numberWithLongLong: nearable.currentMotionStateDuration]
		forKey: @"currentMotionStateDuration"];
	[dict setValue: [NSNumber numberWithLongLong: nearable.previousMotionStateDuration]
		forKey: @"previousMotionStateDuration"];
	[dict setValue: [NSNumber numberWithBool: nearable.isMoving]
		forKey: @"isMoving"];
	[dict setValue: [NSNumber numberWithInt: nearable.orientation]
		forKey:@"orientation"];
	[dict setValue: [NSNumber numberWithInteger: nearable.xAcceleration]
		forKey:@"xAcceleration"];
	[dict setValue: [NSNumber numberWithInteger: nearable.yAcceleration]
		forKey:@"yAcceleration"];
	[dict setValue: [NSNumber numberWithInteger: nearable.zAcceleration]
		forKey:@"zAcceleration"];
	[dict setValue: [NSNumber numberWithDouble: nearable.temperature]
		forKey: @"temperature"];
	[dict setValue: nearable.power
		forKey:@"power"];
	[dict setValue: [NSNumber numberWithInt: nearable.firmwareState]
		forKey:@"firmwareState"];

	return dict;
}

/**
 * Create an array of nearable dictionary objects from an array of
 * nearables (used to pass data back to JavaScript).
 */
- (NSArray*) nearablesToArray: (NSArray*)nearables
{
	// Convert beacons to a an array of property-value objects.
	NSMutableArray* array = [NSMutableArray array];
	for (ESTNearable* nearable in nearables)
	{
		[array addObject: [self nearableToDictionary: nearable]];
	}

	return array;
}

#pragma mark - Nearble ranging

/**
 * Start Nearble ranging for identifier.
 */
- (void) nearables_startRangingForIdentifier: (CDVInvokedUrlCommand*)command
{
	//NSLog(@"OBJC startRangingForIdentifier");

	// Get identifier passed from JavaScript.
	NSString* identifier = [command argumentAtIndex: 0];

	// Stop any ongoing ranging for the given identifier.
	// Only one callback at a time may be ranging a specific identifier.
	// Multiple callbacks cannot range the same identifer.
	[self helper_stopRangingForIdentifier: identifier];

	// Save callback id for the identifier.
	[self.callbackIds_nearablesRangingIdentifier
		setObject: command.callbackId
		forKey: identifier];

	// Start ranging.
	[self.nearableManager startRangingForIdentifier: identifier];
}

/**
 * Stop Nearble ranging for identifier.
 */
- (void) nearables_stopRangingForIdentifier: (CDVInvokedUrlCommand*)command
{
	// Get identifier passed from JavaScript.
	NSString* identifier = [command argumentAtIndex: 0];

	// Stop ranging.
	[self helper_stopRangingForIdentifier: identifier];

	// Respond to JavaScript with OK.
	[self.commandDelegate
		sendPluginResult: [CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
		callbackId: command.callbackId];
}

- (void) helper_stopRangingForIdentifier: (NSString*)identifier
{
	// Stop ranging the identifier.
	[self.nearableManager stopRangingForIdentifier: identifier];

	// Clear any existing callback.
	NSString* callbackId = [self.callbackIds_nearablesRangingIdentifier
		objectForKey: identifier];
	if (nil != callbackId)
	{
		// Clear callback on the JS side.
		CDVPluginResult* result = [CDVPluginResult
			resultWithStatus: CDVCommandStatus_NO_RESULT];
		[result setKeepCallbackAsBool: NO];
		[self.commandDelegate
			sendPluginResult: result
			callbackId: callbackId];

		// Clear callback id.
		[self.callbackIds_nearablesRangingIdentifier
			removeObjectForKey: identifier];
	}
}

/**
 * Nearable identifier ranging event.
 */
 - (void) nearableManager: (ESTNearableManager*)manager
 	didRangeNearable: (ESTNearable *)nearable
{
	NSString* callbackId = [self.callbackIds_nearablesRangingIdentifier
		objectForKey: nearable.identifier];
	if (nil != callbackId)
	{
		// Create dictionary with result.
		NSDictionary* resultDictionary = [self nearableToDictionary: nearable];

		// Pass result to JavaScript callback.
		CDVPluginResult* result = [CDVPluginResult
				resultWithStatus: CDVCommandStatus_OK
				messageAsDictionary: resultDictionary];
		[result setKeepCallbackAsBool: YES];
		[self.commandDelegate
			sendPluginResult: result
			callbackId: callbackId];
	}
}

/**
 * Start Nearable ranging for type.
 */
- (void) nearables_startRangingForType: (CDVInvokedUrlCommand*)command
{
	//NSLog(@"OBJC startRangingForType");

	// Get type passed from JavaScript.
	NSNumber* type = [command argumentAtIndex: 0];

	// Stop any ongoing ranging for the given type.
	// Only one callback at a time may be ranging a specific type.
	// Multiple callbacks cannot range the same type.
	[self helper_stopRangingForType: type];

	// Save callback id for the identifier.
	[self.callbackIds_nearablesRangingType
		setObject: command.callbackId
		forKey: type];

	// Start ranging.
	[self.nearableManager startRangingForType: [type intValue]];
}

/**
 * Stop Nearable ranging for type.
 */
- (void) nearables_stopRangingForType: (CDVInvokedUrlCommand*)command
{
	// Get type passed from JavaScript.
	NSNumber* type = [command argumentAtIndex: 0];

	// Stop ranging.
	[self helper_stopRangingForType: type];

	// Respond to JavaScript with OK.
	[self.commandDelegate
		sendPluginResult:[CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
		callbackId: command.callbackId];
}

- (void) helper_stopRangingForType: (NSNumber*)type
{
	// Stop ranging the type.
	[self.nearableManager stopRangingForType: [type intValue]];

	// Clear any existing callback.
	NSString* callbackId = [self.callbackIds_nearablesRangingType
		objectForKey: type];
	if (nil != callbackId)
	{
		// Clear callback on the JS side.
		CDVPluginResult* result = [CDVPluginResult
			resultWithStatus: CDVCommandStatus_NO_RESULT];
		[result setKeepCallbackAsBool: NO];
		[self.commandDelegate
			sendPluginResult: result
			callbackId: callbackId];

		// Clear callback id.
		[self.callbackIds_nearablesRangingType
			removeObjectForKey: type];
	}
}

/**
 * Nearable type ranging event.
 */
- (void) nearableManager: (ESTNearableManager*) manager
	didRangeNearables: (NSArray*)nearables
	withType: (ESTNearableType)type
{
	NSString* callbackId = [self.callbackIds_nearablesRangingType
		objectForKey: [NSNumber numberWithInt: type]];
	if (nil != callbackId)
	{
		// Create dictionary with result.
		NSArray* resultArray = [self nearablesToArray: nearables];

		// Pass result to JavaScript callback.
		CDVPluginResult* result = [CDVPluginResult
				resultWithStatus: CDVCommandStatus_OK
				messageAsArray: resultArray];
		[result setKeepCallbackAsBool: YES];
		[self.commandDelegate
			sendPluginResult: result
			callbackId: callbackId];
	}
}

/**
 * Nearable ranging error event.
 */
- (void) nearableManager: (ESTNearableManager*)manager
	rangingFailedWithError: (NSError*)error
{
	// Send error message to all ranging callbacks.

	for (NSString* key in self.callbackIds_nearablesRangingIdentifier)
	{
    	NSString* callbackId = [self.callbackIds_nearablesRangingIdentifier objectForKey:key];
		if (nil != callbackId)
		{
			// Pass error message to JavaScript.
			[self.commandDelegate
				sendPluginResult: [CDVPluginResult
					resultWithStatus: CDVCommandStatus_ERROR
					messageAsString: error.localizedDescription]
				callbackId: callbackId];
		}
	}

	for (NSNumber* key in self.callbackIds_nearablesRangingType)
	{
    	NSString* callbackId = [self.callbackIds_nearablesRangingType objectForKey:key];
		if (nil != callbackId)
		{
			// Pass error message to JavaScript.
			[self.commandDelegate
				sendPluginResult: [CDVPluginResult
					resultWithStatus: CDVCommandStatus_ERROR
					messageAsString: error.localizedDescription]
				callbackId: callbackId];
		}
	}
}

/**
 * Stop ranging all Nearables.
 */
- (void) nearables_stopRanging: (CDVInvokedUrlCommand*)command
{
	// Stop ranging.
	[self.nearableManager stopRanging];

	// Clear all callbacks.

	for (NSString* key in self.callbackIds_nearablesRangingIdentifier)
	{
    	NSString* callbackId = [self.callbackIds_nearablesRangingIdentifier objectForKey: key];
		if (nil != callbackId)
		{
			// Clear callback on the JS side.
			CDVPluginResult* result = [CDVPluginResult
				resultWithStatus: CDVCommandStatus_NO_RESULT];
			[result setKeepCallbackAsBool: NO];
			[self.commandDelegate
				sendPluginResult: result
				callbackId: callbackId];
		}
	}

	for (NSNumber* key in self.callbackIds_nearablesRangingType)
	{
    	NSString* callbackId = [self.callbackIds_nearablesRangingType objectForKey: key];
		if (nil != callbackId)
		{
			// Clear callback on the JS side.
			CDVPluginResult* result = [CDVPluginResult
				resultWithStatus: CDVCommandStatus_NO_RESULT];
			[result setKeepCallbackAsBool: NO];
			[self.commandDelegate
				sendPluginResult: result
				callbackId: callbackId];
		}
	}

	// Reset callback dictionaries.
	self.callbackIds_nearablesRangingIdentifier = [NSMutableDictionary new];
	self.callbackIds_nearablesRangingType = [NSMutableDictionary new];

	// Respond to JavaScript with OK.
	[self.commandDelegate
		sendPluginResult:[CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
		callbackId: command.callbackId];
}

#pragma mark - Nearable monitoring

/**
 * Start Nearble monitoring for identifier.
 */
- (void) nearables_startMonitoringForIdentifier: (CDVInvokedUrlCommand*)command
{
	NSLog(@"OBJC nearables_startMonitoringForIdentifier");

	// Get identifier passed from JavaScript.
	NSString* identifier = [command argumentAtIndex: 0];

	// Stop any ongoing monitoring for the given identifier.
	// Only one callback at a time may be monitoring a specific identifier.
	// Multiple callbacks cannot monitor the same identifer.
	[self helper_stopMonitoringForIdentifier: identifier];

	// Save callback id for the identifier.
	[self.callbackIds_nearablesMonitoringIdentifier
		setObject: command.callbackId
		forKey: identifier];

	// Start monitoring.
	[self.nearableManager startMonitoringForIdentifier: identifier];
}

/**
 * Stop Nearble monitoring for identifier.
 */
- (void) nearables_stopMonitoringForIdentifier: (CDVInvokedUrlCommand*)command
{
	// Get identifier passed from JavaScript.
	NSString* identifier = [command argumentAtIndex: 0];

	// Stop monitoring.
	[self helper_stopMonitoringForIdentifier: identifier];

	// Respond to JavaScript with OK.
	[self.commandDelegate
		sendPluginResult: [CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
		callbackId: command.callbackId];
}

- (void) helper_stopMonitoringForIdentifier: (NSString*)identifier
{
	// Stop monitoring the identifier.
	[self.nearableManager stopMonitoringForIdentifier: identifier];

	// Clear any existing callback.
	NSString* callbackId = [self.callbackIds_nearablesMonitoringIdentifier
		objectForKey: identifier];
	if (nil != callbackId)
	{
		// Clear callback on the JS side.
		CDVPluginResult* result = [CDVPluginResult
			resultWithStatus: CDVCommandStatus_NO_RESULT];
		[result setKeepCallbackAsBool: NO];
		[self.commandDelegate
			sendPluginResult: result
			callbackId: callbackId];

		// Clear callback id.
		[self.callbackIds_nearablesMonitoringIdentifier
			removeObjectForKey: identifier];
	}
}

/**
 * Nearable identifier monitoring enter event.
 */
 - (void) nearableManager: (ESTNearableManager *)manager
 	didEnterIdentifierRegion: (NSString *)identifier
{
	NSString* callbackId = [self.callbackIds_nearablesMonitoringIdentifier
		objectForKey: identifier];
	if (nil != callbackId)
	{
		// Create result object.
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity: 4];
		[dict setValue: identifier forKey:@"identifier"];
		[dict setValue: @"inside" forKey:@"state"];

		// Send result.
		CDVPluginResult* result = [CDVPluginResult
			resultWithStatus: CDVCommandStatus_OK
			messageAsDictionary: dict];
		[result setKeepCallback: [NSNumber numberWithBool: YES]];
		[self.commandDelegate
			sendPluginResult: result
			callbackId: callbackId];
	}
}

/**
 * Nearable identifier monitoring exit event.
 */
- (void) nearableManager: (ESTNearableManager *)manager
	didExitIdentifierRegion: (NSString *)identifier
{
	NSString* callbackId = [self.callbackIds_nearablesMonitoringIdentifier
		objectForKey: identifier];
	if (nil != callbackId)
	{
		// Create result object.
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity: 4];
		[dict setValue: identifier forKey:@"identifier"];
		[dict setValue: @"outside" forKey:@"state"];

		// Send result.
		CDVPluginResult* result = [CDVPluginResult
			resultWithStatus: CDVCommandStatus_OK
			messageAsDictionary: dict];
		[result setKeepCallback: [NSNumber numberWithBool: YES]];
		[self.commandDelegate
			sendPluginResult: result
			callbackId: callbackId];
	}
}

/**
 * Start Nearble monitoring for type.
 */
- (void) nearables_startMonitoringForType: (CDVInvokedUrlCommand*)command
{
	NSLog(@"OBJC nearables_startMonitoringForType");

	// Get type passed from JavaScript.
	NSNumber* type = [command argumentAtIndex: 0];

	// Stop any ongoing monitoring for the given type.
	// Only one callback at a time may be monitoring a specific type.
	// Multiple callbacks cannot monitor the same type.
	[self helper_stopMonitoringForType: type];

	// Save callback id for the type.
	[self.callbackIds_nearablesMonitoringType
		setObject: command.callbackId
		forKey: type];

	// Start monitoring.
	[self.nearableManager startMonitoringForType: [type intValue]];
}

/**
 * Stop Nearble monitoring for type.
 */
- (void) nearables_stopMonitoringForType: (CDVInvokedUrlCommand*)command
{
	// Get type passed from JavaScript.
	NSNumber* type = [command argumentAtIndex: 0];

	// Stop monitoring.
	[self helper_stopMonitoringForType: type];

	// Respond to JavaScript with OK.
	[self.commandDelegate
		sendPluginResult: [CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
		callbackId: command.callbackId];
}

- (void) helper_stopMonitoringForType: (NSNumber*)type
{
	// Stop monitoring the type.
	[self.nearableManager stopMonitoringForType: [type intValue]];

	// Clear any existing callback.
	NSString* callbackId = [self.callbackIds_nearablesMonitoringType
		objectForKey: type];
	if (nil != callbackId)
	{
		// Clear callback on the JS side.
		CDVPluginResult* result = [CDVPluginResult
			resultWithStatus: CDVCommandStatus_NO_RESULT];
		[result setKeepCallbackAsBool: NO];
		[self.commandDelegate
			sendPluginResult: result
			callbackId: callbackId];

		// Clear callback id.
		[self.callbackIds_nearablesMonitoringType
			removeObjectForKey: type];
	}
}

/**
 * Nearable type monitoring enter event.
 */
 - (void) nearableManager: (ESTNearableManager *)manager
 	didEnterTypeRegion: (ESTNearableType)type
{
	NSLog(@"OBJC nearableManager didEnterTypeRegion");

	NSString* callbackId = [self.callbackIds_nearablesMonitoringType
		objectForKey: [NSNumber numberWithInt: type]];
	if (nil != callbackId)
	{
		// Create result object.
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity: 4];
		[dict setValue: [NSNumber numberWithInt: type] forKey:@"type"];
		[dict setValue: @"inside" forKey:@"state"];

		// Send result.
		CDVPluginResult* result = [CDVPluginResult
			resultWithStatus: CDVCommandStatus_OK
			messageAsDictionary: dict];
		[result setKeepCallback: [NSNumber numberWithBool: YES]];
		[self.commandDelegate
			sendPluginResult: result
			callbackId: callbackId];
	}
}

/**
 * Nearable type monitoring exit event.
 */
- (void) nearableManager: (ESTNearableManager *)manager
	didExitTypeRegion: (ESTNearableType)type
{
	NSLog(@"OBJC nearableManager didExitTypeRegion");

	NSString* callbackId = [self.callbackIds_nearablesMonitoringType
		objectForKey: [NSNumber numberWithInt: type]];
	if (nil != callbackId)
	{
		// Create result object.
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity: 4];
		[dict setValue: [NSNumber numberWithInt: type] forKey:@"type"];
		[dict setValue: @"outside" forKey:@"state"];

		// Send result.
		CDVPluginResult* result = [CDVPluginResult
			resultWithStatus: CDVCommandStatus_OK
			messageAsDictionary: dict];
		[result setKeepCallback: [NSNumber numberWithBool: YES]];
		[self.commandDelegate
			sendPluginResult: result
			callbackId: callbackId];
	}
}

- (void) nearableManager: (ESTNearableManager *)manager
	monitoringFailedWithError:(NSError *)error
{
	NSLog(@"OBJC nearableManager monitoringFailedWithError: %@", error.localizedDescription);

	// Send error message to all monitoring callbacks.

	for (NSString* key in self.callbackIds_nearablesMonitoringIdentifier)
	{
    	NSString* callbackId = [self.callbackIds_nearablesMonitoringIdentifier objectForKey:key];
		if (nil != callbackId)
		{
			// Pass error message to JavaScript.
			[self.commandDelegate
				sendPluginResult: [CDVPluginResult
					resultWithStatus: CDVCommandStatus_ERROR
					messageAsString: error.localizedDescription]
				callbackId: callbackId];
		}
	}

	for (NSNumber* key in self.callbackIds_nearablesMonitoringType)
	{
    	NSString* callbackId = [self.callbackIds_nearablesMonitoringType objectForKey:key];
		if (nil != callbackId)
		{
			// Pass error message to JavaScript.
			[self.commandDelegate
				sendPluginResult: [CDVPluginResult
					resultWithStatus: CDVCommandStatus_ERROR
					messageAsString: error.localizedDescription]
				callbackId: callbackId];
		}
	}
}

/**
 * Stop monitoring all Nearables.
 */
- (void) nearables_stopMonitoring: (CDVInvokedUrlCommand*)command
{
	// Stop monitoring.
	[self.nearableManager stopMonitoring];

	// Clear all callbacks.

	for (NSString* key in self.callbackIds_nearablesMonitoringIdentifier)
	{
    	NSString* callbackId = [self.callbackIds_nearablesMonitoringIdentifier objectForKey: key];
		if (nil != callbackId)
		{
			// Clear callback on the JS side.
			CDVPluginResult* result = [CDVPluginResult
				resultWithStatus: CDVCommandStatus_NO_RESULT];
			[result setKeepCallbackAsBool: NO];
			[self.commandDelegate
				sendPluginResult: result
				callbackId: callbackId];
		}
	}

	for (NSNumber* key in self.callbackIds_nearablesMonitoringType)
	{
    	NSString* callbackId = [self.callbackIds_nearablesMonitoringType objectForKey: key];
		if (nil != callbackId)
		{
			// Clear callback on the JS side.
			CDVPluginResult* result = [CDVPluginResult
				resultWithStatus: CDVCommandStatus_NO_RESULT];
			[result setKeepCallbackAsBool: NO];
			[self.commandDelegate
				sendPluginResult: result
				callbackId: callbackId];
		}
	}

	// Reset callback dictionaries.
	self.callbackIds_nearablesMonitoringIdentifier = [NSMutableDictionary new];
	self.callbackIds_nearablesMonitoringType = [NSMutableDictionary new];

	// Respond to JavaScript with OK.
	[self.commandDelegate
		sendPluginResult:[CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
		callbackId: command.callbackId];
}

#pragma mark - Estimote Triggers Implementation

/*********************************************************/
/************ Estimote Triggers Implementation ***********/
/*********************************************************/

// **************** Initialise/release ****************

- (void) triggers_pluginInitialize
{
	self.triggerManager = [ESTTriggerManager new];
	self.triggerManager.delegate = self;

	self.triggers = [NSMutableDictionary new];
}

- (void) triggers_onReset
{
	for (NSString* key in self.triggers)
	{
    	ESTCDVTrigger* trigger = self.triggers[key];
		if (nil != trigger)
		{
			[self.triggerManager stopMonitoringForTriggerWithIdentifier:
				trigger.triggerIdentifier];
		}
	}

	self.triggers = [NSMutableDictionary new];
}

// Helper method.
- (void) sendTriggerEventToJavaScript: (NSDictionary*) event
{
	// Trigger object holds callback id.
	ESTCDVTrigger* trigger = [self.triggers objectForKey: event[@"triggerIdentifier"]];

	// Send result.
	CDVPluginResult* result = [CDVPluginResult
		resultWithStatus: CDVCommandStatus_OK
		messageAsDictionary: event];
	[result setKeepCallback: [NSNumber numberWithBool: YES]];
	[self.commandDelegate
		sendPluginResult: result
		callbackId: trigger.callbackId];
}

// **************** JavaScript API implementation ****************

/**
 * Start monitoring for a trigger. Create rule objects and set up
 * callback to JavaScript for monitoring updates and trigger events.
 */
- (void) triggers_startMonitoringForTrigger: (CDVInvokedUrlCommand*)command
{
	NSLog(@"OBJC triggers_startMonitoringForTrigger");

	// Get command parameters.
	NSDictionary* jsTrigger = [command argumentAtIndex: 0];
	NSString* triggerIdentifier = jsTrigger[@"triggerIdentifier"];
	NSArray* jsRules = jsTrigger[@"rules"];

	// Trigger must NOT exist.
	if (nil != self.triggers[triggerIdentifier])
	{
		// Pass error to JavaScript.
		[self.commandDelegate
			sendPluginResult:[CDVPluginResult
				resultWithStatus:CDVCommandStatus_ERROR
				messageAsString: @"Trigger already exists"]
			callbackId: command.callbackId];

		// Abort.
		return;
	}

	// Create custom trigger holder object. It is stored
	// in the triggers dictionary.
	ESTCDVTrigger* trigger = [ESTCDVTrigger new];
	trigger.triggerIdentifier = triggerIdentifier;
	trigger.callbackId = command.callbackId;
	[self.triggers setValue: trigger forKey: triggerIdentifier];

	// Create native rules for all JavaScript rules.
	NSMutableArray* nativeRules = [NSMutableArray array];
	for (NSDictionary* jsRule in jsRules)
	{
		int ruleType = [jsRule[@"ruleType"] intValue];
		NSString* ruleIdentifier = jsRule[@"ruleIdentifier"];

		// Create rule objects based on rule type.
		if (ruleType == EST_CDV_RULE_TYPE_GENERIC)
		{
			ESTCDVRuleGeneric* rule = [ESTCDVRuleGeneric new];
			rule.triggerIdentifier = triggerIdentifier;
			rule.ruleIdentifier = ruleIdentifier;
			rule.pluginManager = self;
			[trigger.nativeRules setValue: rule forKey: ruleIdentifier];
			[nativeRules addObject: rule];
			NSLog(@"Adding EST_CDV_RULE_TYPE_GENERIC");
		}
		else if (ruleType == EST_CDV_RULE_TYPE_NEARABLE_IDENTIFIER)
		{
			ESTCDVRuleNearable* rule = [[ESTCDVRuleNearable alloc]
				initWithNearableIdentifier: jsRule[@"nearableIdentifier"]];
			rule.triggerIdentifier = triggerIdentifier;
			rule.ruleIdentifier = ruleIdentifier;
			rule.pluginManager = self;
			[trigger.nativeRules setValue: rule forKey: ruleIdentifier];
			[nativeRules addObject: rule];
			NSLog(@"Adding EST_CDV_RULE_TYPE_NEARABLE_IDENTIFIER");
		}
		else if (ruleType == EST_CDV_RULE_TYPE_NEARABLE_TYPE)
		{
			ESTCDVRuleNearable* rule = [[ESTCDVRuleNearable alloc]
				initWithNearableType: [jsRule[@"nearableType"] intValue]];
			rule.triggerIdentifier = triggerIdentifier;
			rule.ruleIdentifier = ruleIdentifier;
			rule.pluginManager = self;
			[trigger.nativeRules setValue: rule forKey: ruleIdentifier];
			[nativeRules addObject: rule];
			NSLog(@"Adding EST_CDV_RULE_TYPE_NEARABLE_TYPE");
		}
		else if (ruleType == EST_CDV_RULE_TYPE_IN_RANGE_OF_NEARABLE_IDENTIFIER)
		{
			ESTProximityRule* rule = [ESTProximityRule
				inRangeOfNearableIdentifier: jsRule[@"nearableIdentifier"]];
			[nativeRules addObject: rule];
			NSLog(@"Adding EST_CDV_RULE_TYPE_IN_RANGE_OF_NEARABLE_IDENTIFIER");
		}
		else if (ruleType == EST_CDV_RULE_TYPE_IN_RANGE_OF_NEARABLE_TYPE)
		{
			ESTProximityRule* rule = [ESTProximityRule
				inRangeOfNearableType: [jsRule[@"nearableType"] intValue]];
			[nativeRules addObject: rule];
			NSLog(@"Adding EST_CDV_RULE_TYPE_IN_RANGE_OF_NEARABLE_TYPE");
		}
		else if (ruleType == EST_CDV_RULE_TYPE_OUTSIDE_RANGE_OF_NEARABLE_IDENTIFIER)
		{
			ESTProximityRule* rule = [ESTProximityRule
				outsideRangeOfNearableIdentifier: jsRule[@"nearableIdentifier"]];
			[nativeRules addObject: rule];
			NSLog(@"Adding EST_CDV_RULE_TYPE_OUTSIDE_RANGE_OF_NEARABLE_IDENTIFIER");
		}
		else if (ruleType == EST_CDV_RULE_TYPE_OUTSIDE_RANGE_OF_NEARABLE_TYPE)
		{
			ESTProximityRule* rule = [ESTProximityRule
				outsideRangeOfNearableType: [jsRule[@"nearableType"] intValue]];
			[nativeRules addObject: rule];
			NSLog(@"Adding EST_CDV_RULE_TYPE_OUTSIDE_RANGE_OF_NEARABLE_TYPE");
		}
	}

	// Create native trigger with the rules.
	trigger.nativeTrigger = [[ESTTrigger alloc]
		initWithRules: nativeRules
		identifier: triggerIdentifier];

	// Start monitoring.
	[self.triggerManager startMonitoringForTrigger: trigger.nativeTrigger];
}

/**
 * Stop monitoring for a trigger. Destroy rule objects.
 */
- (void) triggers_stopMonitoringForTrigger: (CDVInvokedUrlCommand*)command
{
	NSLog(@"OBJC triggers_stopMonitoringForTrigger");

	// Get trigger identifier.
	NSString* triggerIdentifier = [command argumentAtIndex: 0];

	// Trigger must exist.
	ESTCDVTrigger* trigger = self.triggers[triggerIdentifier];
	if (nil == trigger)
	{
		// Pass error to JavaScript.
		[self.commandDelegate
			sendPluginResult:[CDVPluginResult
				resultWithStatus:CDVCommandStatus_ERROR
				messageAsString: @"Trigger does not exist"]
			callbackId: command.callbackId];

		// Abort.
		return;
	}

	// Stop trigger.
	[self.triggerManager stopMonitoringForTriggerWithIdentifier: triggerIdentifier];

	// Clear JavaScript trigger callback.
	CDVPluginResult* result = [CDVPluginResult
		resultWithStatus: CDVCommandStatus_NO_RESULT];
	[result setKeepCallbackAsBool: NO];
	[self.commandDelegate
		sendPluginResult: result
		callbackId: trigger.callbackId];

	// TODO: Clean up!
	[self.triggers removeObjectForKey: triggerIdentifier];

	// Respond to JavaScript with OK.
	[self.commandDelegate
		sendPluginResult: [CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
		callbackId: command.callbackId];
}

/**
 * Update state for a rule. This command does not return
 * anything to JavaScript. It is called by JavaScript library
 * code, not by application code.
 */
- (void) triggers_updateRuleState: (CDVInvokedUrlCommand*)command
{
	NSLog(@"OBJC triggers_updateRuleState");

	// Get command parameters.
	NSString* triggerIdentifier = [command argumentAtIndex: 0];
	NSString* ruleIdentifier = [command argumentAtIndex: 1];
	BOOL state = [[command argumentAtIndex: 2] boolValue];

	// Get rule and set state.
	ESTCDVTrigger* trigger = self.triggers[triggerIdentifier];
	ESTRule* rule = trigger.nativeRules[ruleIdentifier];
	rule.state = state;
}

- (void) triggerManager: (ESTTriggerManager*)manager
	triggerChangedState: (ESTTrigger*)trigger
{
	NSLog(@"triggerManager:triggerChangedState:");

	NSMutableDictionary* event = [NSMutableDictionary dictionaryWithCapacity: 8];

	[event setValue: @"triggerChangedState" forKey: @"eventType"];
	[event setValue: trigger.identifier forKey: @"triggerIdentifier"];
	[event setValue: [NSNumber numberWithBool: trigger.state] forKey: @"triggerState"];

	[self sendTriggerEventToJavaScript: event];
}

#pragma mark - Bluetooth State Implementation

/*********************************************************/
/************ Bluetooth State Implementation *************/
/*********************************************************/

/**
 * Read Bluetooth state.
 */
- (void) bluetooth_bluetoothState: (CDVInvokedUrlCommand*)command
{
	// Return value to JavaScript.
	[self.commandDelegate
		sendPluginResult: [CDVPluginResult
			resultWithStatus: CDVCommandStatus_OK
			messageAsBool: self.bluetoothState]
		callbackId: command.callbackId];
}

- (void) bluetooth_pluginInitialize
{
	// Create CoreBluetooth manager.
	self.bluetoothManager = [[CBCentralManager alloc]
		initWithDelegate: self
		queue: dispatch_get_main_queue()
		options: @{CBCentralManagerOptionShowPowerAlertKey: @(NO)}];

	// This sets the initial state.
	[self centralManagerDidUpdateState: self.bluetoothManager];
}

- (void) bluetooth_onReset
{
	self.bluetoothManager = nil;
}

#pragma mark - Bluetooth on/off handler

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
	if ([central state] == CBCentralManagerStatePoweredOn)
	{
		self.bluetoothState = YES;
	}
	else
	{
		self.bluetoothState = NO;
	}
}

@end // End of implementation of class EstimoteBeacons

#pragma mark - Trigger object

// **************** Trigger object ****************

@implementation ESTCDVTrigger

- init
{
	self = [super init];
	self.nativeRules = [NSMutableDictionary new];
	return self;
}

@end

// **************** Generic rule ****************

@implementation ESTCDVRuleGeneric

- (void) update
{
	NSLog(@"ESTCDVRuleGeneric update");

    [super update];

	NSMutableDictionary* event = [NSMutableDictionary dictionaryWithCapacity: 8];

	[event setValue: @"update" forKey: @"eventType"];
	[event setValue: self.ruleIdentifier forKey: @"ruleIdentifier"];
	[event setValue: self.triggerIdentifier forKey: @"triggerIdentifier"];

	[self.pluginManager sendTriggerEventToJavaScript: event];
}

@end

// **************** Nearable rule ****************

@implementation ESTCDVRuleNearable

- (void) updateWithNearable: (ESTNearable*)nearable
{
	NSLog(@"ESTCDVRuleNearable updateWithNearable");

    [super updateWithNearable: nearable];

	NSMutableDictionary* event = [NSMutableDictionary dictionaryWithCapacity: 8];

	[event setValue: @"update" forKey: @"eventType"];
	[event setValue: self.ruleIdentifier forKey: @"ruleIdentifier"];
	[event setValue: self.triggerIdentifier forKey: @"triggerIdentifier"];
	[event
		setValue: [self.pluginManager nearableToDictionary: nearable]
		forKey: @"nearable"];

	[self.pluginManager sendTriggerEventToJavaScript: event];
}

@end
