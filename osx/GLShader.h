#import <GLKit/GLKit.h>
#import "RCTBridgeModule.h"

@interface GLShader: NSObject

@property NSOpenGLContext  *context;
@property NSString *vert;
@property NSString *frag;
@property NSDictionary *uniformTypes;

NS_ENUM(NSInteger) {
     GLContextFailure = 87001,
     GLLinkingFailure = 87002,
     GLCompileFailure = 87003,
     GLNotAProgram    = 87004
 };

/**
 * Create a new shader with a vertex and fragment
 */
- (instancetype)initWithContext: (NSOpenGLContext *)context withName:(NSString *)name withVert:(NSString *)vert withFrag:(NSString *)frag;

/**
 * Bind the shader program as the current one
 */
- (void) bind;

/**
 * Check the shader validity
 */
- (void) validate;

- (bool) ensureCompiles: (NSError**)error;
/**
 * Set the value of an uniform
 */
- (void) setUniform: (NSString *)name withValue:(id)obj;

@end
