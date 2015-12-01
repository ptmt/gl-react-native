#import <GLKit/GLKit.h>
#import "RCTBridge.h"
#import "GLImageData.h"

GLImageData* genPixelsWithImage (NSImage *image);

@interface GLTexture: NSObject

@property NSOpenGLContext *context;
@property GLuint handle;

- (instancetype)init;
- (int)bind: (int)unit;
- (void)bind;

- (void)setShapeWithWidth:(float)width withHeight:(float)height;

- (void)setPixels: (GLImageData *)data;
- (void)setPixelsEmpty;
- (void)setPixelsRandom: (int)width withHeight:(int)height;
- (void)setPixelsWithImage: (NSImage *)image;
- (void)setPixelsWithView: (NSView *)view;

@end
