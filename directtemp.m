#include <stdio.h>
#include <unistd.h>
#import "USBAgent.h"

@interface QTIAgent : USBAgent

@property NSString *temperature;

@end

@implementation QTIAgent

- (id)init;
{
    if (self = [super init]) {
        self.temperature = nil;
    }
    
    return self;
}

- (NSString *)getTemperature;
{
    @autoreleasepool {
        self.vendorID = 0x1DFD;
        self.productID = 0x0002;
        [self start];   
        uint8_t data[16] = {0x32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
        while (1) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            if (self.temperature != nil) {
                break;
            }
            if (self.devicePluggedIn == TRUE) {
                [self sendReport:data length:16];
            } else {
                self.temperature = @"-9999.0";
                break;
            }
        }
        [self stop];
        return self.temperature;
    }
}

- (void)incomingDataCallback:(NSData *)data;
{
    uint8_t *bytes = (uint8_t *)[data bytes];
	self.temperature = [[NSString alloc] initWithBytes:&bytes[1] length:[data length]-1 encoding:NSUTF8StringEncoding];
    self.temperature = [self.temperature stringByReplacingOccurrencesOfString:@"\x0D\x0A" withString:@""];
}

@end

int main(int argc, char *argv[])
{
    int opt;
    BOOL verbose = FALSE;
    BOOL toF = FALSE;
    
    while ((opt = getopt(argc, argv, "fv")) != -1) { 
        switch(opt) 
        { 
            case 'f':
                toF = TRUE;
                break;
            case 'v': 
                verbose = TRUE;
                break; 
        } 
    } 
    
    @autoreleasepool {
        QTIAgent *a = [QTIAgent new];
        a.verbose = verbose;
        [a getTemperature];
        float t = [a.temperature doubleValue];
        if (toF == TRUE && t != -9999.0) {
            t = t * 1.8 + 32.0;
        }
        printf("%.2f", t);
    }
}

