#import "USBAgent.h"

@implementation USBAgent

#pragma mark -
#pragma mark C Function Prototypes

static Boolean IOHIDDevice_GetLongProperty(IOHIDDeviceRef inIOHIDDeviceRef, CFStringRef inKey, long *outValue);

static void Handle_DeviceRemovalCallback(void * inContext, IOReturn inResult, void * inSender, IOHIDDeviceRef inIOHIDDeviceRef);

static void Handle_DeviceMatchingCallback(void *         inContext,             // context from IOHIDManagerRegisterDeviceMatchingCallback
                                          IOReturn       inResult,              // the result of the matching operation
                                          void *         inSender,              // the IOHIDManagerRef for the new device
                                          IOHIDDeviceRef inIOHIDDeviceRef);     // the new HID device

static void Handle_IOHIDDeviceInputReportCallback(void *          inContext,		// context from IOHIDDeviceRegisterInputReportCallback
                                                  IOReturn        inResult,         // completion result for the input report operation
                                                  void *          inSender,         // IOHIDDeviceRef of the device this report is from
                                                  IOHIDReportType inType,           // the report type
                                                  uint32_t        inReportID,       // the report ID
                                                  uint8_t *       inReport,         // pointer to the report data
                                                  CFIndex         inReportLength);   // the actual size of the input report


#pragma mark -
#pragma mark Private File-Scoped Methods

- (NSString *)stringForIOReturn:(IOReturn)ioReturn;
{
    NSString *result = nil;
    
    switch (ioReturn)
    {
        case kIOReturnExclusiveAccess:
            result = @"this exclusive access device has already been opened.";
            break;
            
        default:
            result = [NSString stringWithFormat:@"0x%0X", ioReturn];
            break;
            
    }
    
    return result;
}

#pragma mark -
#pragma mark Port Management Methods

- (void)tearDownHidManagerAndCallbacks;
{
	IOHIDManagerClose(gHIDManager, kIOHIDOptionsTypeNone);

#if 0
    /**** CLAIM FROM APPLE ENGINEER AT WWDC11 6/9/11: THE FOLLOWING LINES ARE NOT NEEDED ****/
	IOHIDManagerUnscheduleFromRunLoop(gHIDManager, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	IOHIDManagerRegisterInputValueCallback(gHIDManager, NULL, (__bridge void *)(self));
	IOHIDManagerRegisterDeviceRemovalCallback(gHIDManager, NULL, (__bridge void *)(self));
	IOHIDManagerRegisterDeviceMatchingCallback(gHIDManager, NULL, (__bridge void *)(self));
	/**** CLAIM FROM APPLE ENGINEER AT WWDC11 6/9/11: THE ABOVE LINES ARE NOT NEEDED ****/
#endif
    
	CFRelease(gHIDManager); // Should release our manager
    gHIDManager = nil;
}

- (BOOL)setupHidManagerAndCallbacks;
{
	gHIDManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    
	if (gHIDManager)
	{
        NSDictionary *matchDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInteger:self.vendorID], @kIOHIDVendorIDKey,
                                   [NSNumber numberWithInteger:self.productID], @kIOHIDProductIDKey,
                                   nil];
        
        IOHIDManagerSetDeviceMatching(gHIDManager, (__bridge CFDictionaryRef)matchDict);
        
        // Callbacks for device plugin/removal
        IOHIDManagerRegisterDeviceMatchingCallback(gHIDManager, Handle_DeviceMatchingCallback, (__bridge void *)(self));
        IOHIDManagerRegisterDeviceRemovalCallback(gHIDManager, Handle_DeviceRemovalCallback, (__bridge void *)(self));
        
        // Schedule with the run loop
        IOHIDManagerScheduleWithRunLoop(gHIDManager, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        
        IOReturn ioRet = IOHIDManagerOpen(gHIDManager, kIOHIDOptionsTypeNone);
        if (ioRet != kIOReturnSuccess)
        {
            CFRelease(gHIDManager);
			gHIDManager = nil;
			if (self.verbose == TRUE)
                NSLog(@"Failed to open the IOHID Manager: %@", [self stringForIOReturn:ioRet]);
        }
        else
        {
			if (self.verbose == TRUE)
                NSLog(@"IOHID Manager successfully started.");
        }
    }
	else
	{
		if (self.verbose == TRUE)
    		NSLog(@"Failed to create an IOHID Manager");
	}

    
	return gHIDManager != NULL;
}

#pragma mark -
#pragma mark Public Methods

- (void)dealloc;
{
}

- (NSError *)start;
{    
    NSError *result = nil;
	{
		[self setupHidManagerAndCallbacks];
	}

	return result;
}

- (NSError *)stop;
{
    NSError *result = nil;
    {
        if (nil != gHIDManager)
        {
            [self tearDownHidManagerAndCallbacks];
        }
        self.devicePluggedIn = NO;
    }
    
	return result;
}

- (IOReturn)sendReport:(uint8_t *)reportData length:(CFIndex)length;
{
	if (self.verbose == TRUE)
    	NSLog(@"Sending USB data: %@", [NSData dataWithBytes:reportData length:length]);

    // synchronous
    IOReturn ioReturn = IOHIDDeviceSetReport(gHidDeviceRef,                     // IOHIDDeviceRef for the HID device
                                             kIOHIDReportTypeOutput,            // IOHIDReportType for the report
                                             0,                                 // CFIndex for the report ID
                                             reportData,						// address of report buffer
                                             length);							// length of the report
    if (kIOReturnSuccess != ioReturn)
	{
		if (self.verbose == TRUE)
    	    NSLog(@"IOHIDDeviceSetReport: %@", [self stringForIOReturn:ioReturn]);
	}
	
	return ioReturn;
}

#pragma mark -
#pragma mark HID Callback Methods

- (void)openAndInitDevice:(IOReturn)inResult sender:(void *)inSender device:(IOHIDDeviceRef)inIOHIDDeviceRef;
{
    long reportSize = 0;

    gHidDeviceRef = inIOHIDDeviceRef;
    self.devicePluggedIn = TRUE;
    
    (void)IOHIDDevice_GetLongProperty(inIOHIDDeviceRef, CFSTR(kIOHIDMaxInputReportSizeKey), &reportSize);
    
    if (reportSize && reportSize <= USB_REPORT_SIZE)
    {
		IOHIDDeviceRegisterInputReportCallback(inIOHIDDeviceRef,						// IOHIDDeviceRef for the HID device
											   usbReportBuffer,                         // pointer to the report data (uint8_ts)
											   reportSize,								// number of bytes in the report (CFIndex)
											   Handle_IOHIDDeviceInputReportCallback,	// the callback routine
											   (__bridge void *)(self));									// context passed to callback

		if (self.verbose == TRUE)
            NSLog(@"Device plugged into USB.");
    }
	else
	{
		if (self.verbose == TRUE)
            NSLog(@"Device plugged into USB, but failed to register callback.");
	}
}

- (void)closeAndReleaseDevice:(IOHIDDeviceRef)hidDeviceRef;
{
    self.devicePluggedIn = NO;
	if (self.verbose == TRUE)
        NSLog(@"Device unplugged from USB.");
}

#pragma mark -
#pragma mark HID Methods

static Boolean IOHIDDevice_GetLongProperty(IOHIDDeviceRef inIOHIDDeviceRef, CFStringRef inKey, long *outValue)
{
	Boolean result = FALSE;
    
	if (inIOHIDDeviceRef)
    {
		assert(IOHIDDeviceGetTypeID() == CFGetTypeID(inIOHIDDeviceRef));
        
		CFTypeRef tCFTypeRef = IOHIDDeviceGetProperty(inIOHIDDeviceRef, inKey);
		if (tCFTypeRef) 
        {
			// if this is a number
			if (CFNumberGetTypeID() == CFGetTypeID(tCFTypeRef)) 
            {
				// get it's value
                int32_t value;
				result = (BOOL)CFNumberGetValue((CFNumberRef)tCFTypeRef, kCFNumberSInt32Type, &value);
                *outValue = value;
			}
		}
	}
     
	return (result);
}

static void Handle_DeviceRemovalCallback(void * inContext, IOReturn inResult, void * inSender, IOHIDDeviceRef inIOHIDDeviceRef)
{
    @autoreleasepool {
	USBAgent *self = (__bridge USBAgent *)inContext;
	if (inResult != kIOReturnSuccess)
    {
		if (self.verbose == TRUE)
            NSLog(@"Problem with device removal: %@", [self stringForIOReturn:inResult]);
		return;
	}
	[self closeAndReleaseDevice:inIOHIDDeviceRef];
    }
}


static void Handle_DeviceMatchingCallback(void *         inContext,             // context from IOHIDManagerRegisterDeviceMatchingCallback
                                          IOReturn       inResult,              // the result of the matching operation
                                          void *         inSender,              // the IOHIDManagerRef for the new device
                                          IOHIDDeviceRef inIOHIDDeviceRef)      // the new HID device
{
    @autoreleasepool {
	USBAgent *agent = (__bridge USBAgent *)inContext;
	[agent openAndInitDevice:inResult sender:inSender device:inIOHIDDeviceRef];
    }
}


static void Handle_IOHIDDeviceInputReportCallback(void *          inContext,		// context from IOHIDDeviceRegisterInputReportCallback
                                                  IOReturn        inResult,         // completion result for the input report operation
                                                  void *          inSender,         // IOHIDDeviceRef of the device this report is from
                                                  IOHIDReportType inType,           // the report type
                                                  uint32_t        inReportID,       // the report ID
                                                  uint8_t *       inReport,         // pointer to the report data
                                                  CFIndex         inReportLength)   // the actual size of the input report
{
    @autoreleasepool {
	USBAgent *agent = (__bridge USBAgent *)inContext;

	if (agent.verbose == TRUE)
        NSLog(@"USB report received [%d]: %@", inResult, [NSData dataWithBytes:inReport length:inReportLength]);
    
	[agent incomingDataCallback:[NSData dataWithBytes:inReport length:inReportLength]];
    }
}

// Needs to be implemented by a subclass
- (void)incomingDataCallback:(NSData *)data;
{
	if (self.verbose == TRUE)
    	NSLog(@"Received USB data: %@", data);
}

@end
