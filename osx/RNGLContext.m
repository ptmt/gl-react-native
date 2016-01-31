
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


- (void)_addShader:(nonnull NSNumber *)id
withConfig:(NSDictionary *)config
withOnCompile:(RCTResponseSenderBlock)onCompile
{
  NSString *frag = [RCTConvert NSString:config[@"frag"]];
  NSString *name = [RCTConvert NSString:config[@"name"]];
  if (!frag) {
    RCTLogError(@"Shader '%@': missing frag field", name);
    return;
  }
  GLShader *shader = [[GLShader alloc] initWithContext:_context withName:name withVert:fullViewportVert withFrag:frag];
  NSError *error;
  bool success = [shader ensureCompiles:&error];
  if (onCompile) {
    if (!success) {
      onCompile(@[error.domain]);
    }
    else {
      onCompile(@[[NSNull null],
                  @{
                    @"uniforms": shader.uniformTypes
                    }]);
    }
  }
  else {
    if (!success) {
      RCTLogError(@"Shader '%@': %@", name, error.domain);
    }
  }
  _shaders[id] = shader;
}


static NSString* fullViewportVert = @"attribute vec2 position;varying vec2 uv;void main() {gl_Position = vec4(position,0.0,1.0);uv = vec2(0.5, 0.5) * (position+vec2(1.0, 1.0));}";

NSString* glTypeString (int type) {
  switch (type) {
    case GL_FLOAT: return @"float";
    case GL_FLOAT_VEC2: return @"vec2";
    case GL_FLOAT_VEC3: return @"vec3";
    case GL_FLOAT_VEC4: return @"vec4";
    case GL_INT: return @"int";
    case GL_INT_VEC2: return @"ivec2";
    case GL_INT_VEC3: return @"ivec3";
    case GL_INT_VEC4: return @"ivec4";
    case GL_BOOL: return @"bool";
    case GL_BOOL_VEC2: return @"bvec2";
    case GL_BOOL_VEC3: return @"bvec3";
    case GL_BOOL_VEC4: return @"bvec4";
    case GL_FLOAT_MAT2: return @"mat2";
    case GL_FLOAT_MAT3: return @"mat3";
    case GL_FLOAT_MAT4: return @"mat4";
    case GL_SAMPLER_2D: return @"sampler2D";
    case GL_SAMPLER_CUBE: return @"samplerCube";
  }
  return @"";
}
NSDictionary* glTypesString (NSDictionary *types) {
  NSMutableDictionary *dict = types.mutableCopy;
  for (NSString *key in [dict allKeys]) {
    dict[key] = glTypeString([dict[key] intValue]);
  }
  return dict;
}

- (NSOpenGLContext *) getContext
{
  return _context;
}

RCT_EXPORT_METHOD(addShader:(nonnull NSNumber *)id
                  withConfig:(NSDictionary *)config
                  withOnCompile:(RCTResponseSenderBlock)onCompile) {
      NSString *frag = [RCTConvert NSString:config[@"frag"]];
      NSString *name = [RCTConvert NSString:config[@"name"]];
      if (!frag) {
        RCTLogError(@"Shader '%@': missing frag field", name);
        return;
      }
      GLShader *shader = [[GLShader alloc] initWithContext:_context withName:name withVert:fullViewportVert withFrag:frag];
      NSError *error;
      bool success = [shader ensureCompiles:&error];
      if (onCompile) {
        if (!success) {
          onCompile(@[error.domain]);
        }
        else {
          onCompile(@[[NSNull null],
                      @{
                        @"uniforms": glTypesString(shader.uniformTypes)
                        }]);
        }
      }
      else {
        if (!success) {
          RCTLogError(@"Shader '%@': %@", name, error.domain);
        }
      }
      _shaders[id] = shader;
}

@end

@implementation RCTBridge (RNGLContext)

- (RNGLContext *)rnglContext
{
  return [self moduleForClass:[RNGLContext class]];
}

@end
