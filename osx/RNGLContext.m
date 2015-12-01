
#import "RNGLContext.h"

#import "RCTConvert.h"
#import "RCTLog.h"


@implementation RNGLContext
{
  NSMutableDictionary *_shaders;
  NSOpenGLContext *_context;
  NSMutableDictionary *_fbos;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

- (void)setBridge:(RCTBridge *)bridge
{
    NSOpenGLPixelFormatAttribute attributes[] =
    {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, 24,
        // Must specify the 3.2 Core Profile to use OpenGL 3.2
#if ESSENTIAL_GL_PRACTICES_SUPPORT_GL3
        NSOpenGLPFAOpenGLProfile,
        NSOpenGLProfileVersion3_2Core,
#endif
        0
    };

  NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];

  _context = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];

  if (!_context) {
    RCTLogError(@"Failed to initialize OpenGLES 2.0 context");
  }
  _shaders = @{}.mutableCopy;
  _fbos = @{}.mutableCopy;
}

- (GLShader *) getShader: (NSNumber *)id
{
  return _shaders[id];
}

- (GLFBO *) getFBO: (NSNumber *)id
{
  GLFBO *fbo = _fbos[id];
  if (!fbo) {
    fbo = [[GLFBO alloc] init];
    _fbos[id] = fbo;
  }
  return fbo;
}

- (NSOpenGLContext *) getContext
{
  return _context;
}

static NSString* fullViewportVert = @"attribute vec2 position;varying vec2 uv;void main() {gl_Position = vec4(position,0.0,1.0);uv = vec2(0.5, 0.5) * (position+vec2(1.0, 1.0));}";

RCT_EXPORT_METHOD(addShader:(nonnull NSNumber *)id withConfig:(NSDictionary *)config) {
  NSString *frag = [RCTConvert NSString:config[@"frag"]];
  NSString *name = [RCTConvert NSString:config[@"name"]];
  if (!frag) {
    RCTLogError(@"Shader '%@': missing frag field", name);
    return;
  }
  GLShader *shader = [[GLShader alloc] initWithContext:_context withName:name withVert:fullViewportVert withFrag:frag];
  _shaders[id] = shader;
}

@end

@implementation RCTBridge (RNGLContext)

- (RNGLContext *)rnglContext
{
  return self.modules[RCTBridgeModuleNameForClass([RNGLContext class])];
}

@end