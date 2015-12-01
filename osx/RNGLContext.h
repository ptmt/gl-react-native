
#import <AppKit/AppKit.h>

#import "RCTBridge.h"
#import "GLShader.h"
#import "GLFBO.h"


@interface RNGLContext : NSObject <RCTBridgeModule>

- (GLShader*) getShader: (NSNumber *)id;

- (GLFBO*) getFBO: (NSNumber *)id;

- (NSOpenGLContext *) getContext;

@end


@interface RCTBridge (RNGLContext)

@property (nonatomic, readonly) RNGLContext *rnglContext;

@end
