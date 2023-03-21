#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>

#define USB_REPORT_SIZE 128

@interface USBAgent : NSObject
{
    // USB port management
	IOHIDManagerRef         gHIDManager;
	IOHIDDeviceRef          gHidDeviceRef;
    uint8_t                 usbReportBuffer[USB_REPORT_SIZE];
}

@property uint16_t vendorID;
@property uint16_t productID;
@property BOOL devicePluggedIn;
@property BOOL verbose;

- (NSError *)start;
- (NSError *)stop;
- (IOReturn)sendReport:(uint8_t *)reportData length:(CFIndex)length;

@end
