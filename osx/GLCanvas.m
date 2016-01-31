
#import "RCTBridge.h"
#import "RCTUtils.h"
#import "RCTConvert.h"
#import "RCTEventDispatcher.h"
#import "RCTLog.h"
#import "RNGLContext.h"
#import "GLCanvas.h"
#import "GLShader.h"
#import "GLTexture.h"
#import "GLImage.h"
#import "GLRenderData.h"
#import "NSView+React.h"


NSString* srcResource (id res)
{
  NSString *src;
  if ([res isKindOfClass:[NSString class]]) {
    src = [RCTConvert NSString:res];
  } else {
    BOOL isStatic = [RCTConvert BOOL:res[@"isStatic"]];
    src = [RCTConvert NSString:res[@"path"]];
    if (!src || isStatic) src = [RCTConvert NSString:res[@"uri"]];
  }
  return src;
}
NSArray* diff (NSArray* a, NSArray* b) {
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    for (NSString* k in a) {
        if (![b containsObject:k]) {
            [arr addObject:k];
        }
    }
    return arr;
}

// For reference, see implementation of gl-shader's GLCanvas

@implementation GLCanvas
{
  RCTBridge *_bridge;
  
  GLRenderData *_renderData;
  NSArray *_contentData;
  
  NSArray *_contentTextures;
  NSDictionary *_images; // This caches the currently used images (imageSrc -> GLReactImage)
  
  BOOL _opaque; // opaque prop (if false, the GLCanvas will become transparent)
  
  BOOL _deferredRendering; // This flag indicates a render has been deferred to the next frame (when using contents)
  
  GLint defaultFBO;
  
    NSMutableArray *_preloaded;
    BOOL _dirtyOnLoad;
    BOOL _neverRendered;
    
  NSTimer *animationTimer;
  
    BOOL _needSync;

    NSMutableArray *_captureConfigs;
    BOOL _captureScheduled;

}

- (instancetype)initWithBridge:(RCTBridge *)bridge
{
  if ((self = [super init])) {
    _bridge = bridge;
    _images = @{};
    _preloaded = [[NSMutableArray alloc] init];
      _captureConfigs = [[NSMutableArray alloc] init];
    [self setOpenGLContext:[bridge.rnglContext getContext]];
    [self setPixelFormat:[self openGLContext].pixelFormat];
    //[self setWantsBestResolutionOpenGLSurface:YES];
    //self.contentScaleFactor = RCTScreenScale();
  }
  return self;
}

RCT_NOT_IMPLEMENTED(-init)

-(void)dealloc
{
    _bridge = nil;
    _images = nil;
    _preloaded = nil;
    _captureConfigs = nil;
    _contentData = nil;
    _contentTextures = nil;
    _data = nil;
    _renderData = nil;
    if (animationTimer) {
        [animationTimer invalidate];
        animationTimer = nil;
    }
}


//// Props Setters

-(void)setImagesToPreload:(NSArray *)imagesToPreload
{

  _imagesToPreload = imagesToPreload;
    [self requestSyncData];
}

- (BOOL)isOpaque
{
    return _opaque;
}
- (void)setOpaque:(BOOL)opaque
{
  _opaque = opaque;
//  if (![self wantsLayer]) {
//    CALayer *viewLayer = [CALayer layer];
//    [self setWantsLayer:YES];
//    [self setLayer:viewLayer];
//  }
//  self.layer.opaque = _opaque;
  [self setNeedsDisplay:YES];
}

- (void)setRenderId:(NSNumber *)renderId
{
  if (_nbContentTextures > 0) {
    [self setNeedsDisplay:YES];
  }
}

- (void)setAutoRedraw:(BOOL)autoRedraw
{
  if (autoRedraw) {
    if (!animationTimer)
      animationTimer = // FIXME: can we do better than this?
      [NSTimer scheduledTimerWithTimeInterval:1.0/60.0
                                       target:self
                                     selector:@selector(setNeedsDisplay)
                                     userInfo:nil
                                      repeats:YES];
  }
  else {
    if (animationTimer) {
      [animationTimer invalidate];
    }
  }
}

- (void)setEventsThrough:(BOOL)eventsThrough
{
  _eventsThrough = eventsThrough;
  [self syncEventsThrough];
}

-(void)setVisibleContent:(BOOL)visibleContent
{
  _visibleContent = visibleContent;
  [self syncEventsThrough];
}

- (void)setData:(GLData *)data
{
  _data = data;
  [self requestSyncData];
}

- (void)setNbContentTextures:(NSNumber *)nbContentTextures
{
  [self resizeUniformContentTextures:[nbContentTextures intValue]];
  _nbContentTextures = nbContentTextures;
}



//// Sync methods (called from props setters)

- (void) syncEventsThrough
{
//  self.userInteractionEnabled = !(_eventsThrough);
//  self.superview.userInteractionEnabled = !(_eventsThrough && !_visibleContent);
}

- (void)requestSyncData
{
    _needSync = true;
    [self setNeedsDisplay:YES];
}

- (void)syncData
{
  [[self openGLContext] makeCurrentContext];
  @autoreleasepool {
    
    NSDictionary *prevImages = _images;
    NSMutableDictionary *images = [[NSMutableDictionary alloc] init];
    
    GLRenderData * (^traverseTree) (GLData *data);
    __block __weak GLRenderData * (^weak_traverseTree)(GLData *data);
    weak_traverseTree = traverseTree = ^GLRenderData *(GLData *data) {
      NSNumber *width = data.width;
      NSNumber *height = data.height;
      int fboId = [data.fboId intValue];
      
      NSMutableArray *contextChildren = [[NSMutableArray alloc] init];
      for (GLData *child in data.contextChildren) {
        [contextChildren addObject:weak_traverseTree(child)];
      }
      
      NSMutableArray *children = [[NSMutableArray alloc] init];
      for (GLData *child in data.children) {
        [children addObject:weak_traverseTree(child)];
      }
      
      GLShader *shader = [_bridge.rnglContext getShader:data.shader];
      
      NSDictionary *uniformTypes = [shader uniformTypes];
      NSMutableDictionary *uniforms = [[NSMutableDictionary alloc] init];
      NSMutableDictionary *textures = [[NSMutableDictionary alloc] init];
      int units = 0;
      for (NSString *uniformName in data.uniforms) {
        id value = [data.uniforms objectForKey:uniformName];
        GLenum type = [uniformTypes[uniformName] intValue];
        
          
        if (type == GL_SAMPLER_2D || type == GL_SAMPLER_CUBE) {
          uniforms[uniformName] = [NSNumber numberWithInt:units++];
          if ([value isEqual:[NSNull null]]) {
            GLTexture *emptyTexture = [[GLTexture alloc] init];
            [emptyTexture setPixels:nil];
            textures[uniformName] = emptyTexture;
          }
          else {
            NSString *type = [RCTConvert NSString:value[@"type"]];
            if ([type isEqualToString:@"content"]) {
              int id = [[RCTConvert NSNumber:value[@"id"]] intValue];
              if (id >= [_contentTextures count]) {
                [self resizeUniformContentTextures:id+1];
              }
              textures[uniformName] = _contentTextures[id];
            }
            else if ([type isEqualToString:@"fbo"]) {
              NSNumber *id = [RCTConvert NSNumber:value[@"id"]];
              GLFBO *fbo = [_bridge.rnglContext getFBO:id];
              textures[uniformName] = fbo.color[0];
            }
            else if ([type isEqualToString:@"uri"]) {
              NSString *src = srcResource(value);
              if (!src) {
                RCTLogError(@"texture uniform '%@': Invalid uri format '%@'", uniformName, value);
              }
              
              GLImage *image = images[src];
              if (image == nil) {
                image = prevImages[src];
                if (image != nil)
                  images[src] = image;
              }
              if (image == nil) {
                __weak GLCanvas *weakSelf = self;
                image = [[GLImage alloc] initWithBridge:_bridge withOnLoad:^{
                  if (weakSelf) [weakSelf onImageLoad:src];
                }];
                image.src = src;
                images[src] = image;
              }
              textures[uniformName] = [image getTexture];
            }
            else {
              RCTLogError(@"texture uniform '%@': Unexpected type '%@'", uniformName, type);
            }
          }
        }
        else {
          uniforms[uniformName] = value;
        }
      }
      
      int maxTextureUnits;
      glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &maxTextureUnits);
      if (units > maxTextureUnits) {
        RCTLogError(@"Maximum number of texture reach. got %i >= max %i", units, maxTextureUnits);
      }
      
      for (NSString *uniformName in shader.uniformTypes) {
        if (uniforms[uniformName] == nil) {
          RCTLogError(@"All defined uniforms must be provided. Missing '%@'", uniformName);
        }
      }
      
      return [[GLRenderData alloc]
              initWithShader:shader
              withUniforms:uniforms
              withTextures:textures
              withWidth:(int)width
              withHeight:(int)height
              withFboId:fboId
              withContextChildren:contextChildren
              withChildren:children];
    };
    
    _renderData = traverseTree(_data);
    _images = images;
  }
}

- (void)syncContentTextures
{
    unsigned long max = MIN([_contentData count], [_contentTextures count]);
    for (int i=0; i<max; i++) {
        [_contentTextures[i] setPixels:_contentData[i]];
    }
}

- (bool)syncData:(NSError **)error
{
    @autoreleasepool {

        NSDictionary *prevImages = _images;
        NSMutableDictionary *images = [[NSMutableDictionary alloc] init];

        GLRenderData * (^traverseTree) (GLData *data);
        __block __weak GLRenderData * (^weak_traverseTree)(GLData *data);
        weak_traverseTree = traverseTree = ^GLRenderData *(GLData *data) {
            NSNumber *width = data.width;
            NSNumber *height = data.height;
            NSNumber *pixelRatio = data.pixelRatio;
            int fboId = [data.fboId intValue];

            NSMutableArray *contextChildren = [[NSMutableArray alloc] init];
            for (GLData *child in data.contextChildren) {
                GLRenderData *node = weak_traverseTree(child);
                if (node == nil) return nil;
                [contextChildren addObject:node];
            }

            NSMutableArray *children = [[NSMutableArray alloc] init];
            for (GLData *child in data.children) {
                GLRenderData *node = weak_traverseTree(child);
                if (node == nil) return nil;
                [children addObject:node];
            }

            GLShader *shader = [_bridge.rnglContext getShader:data.shader];
            if (shader == nil) return nil;
            if (![shader ensureCompiles:error]) return nil;

            NSDictionary *uniformTypes = [shader uniformTypes];
            NSMutableDictionary *uniforms = [[NSMutableDictionary alloc] init];
            NSMutableDictionary *textures = [[NSMutableDictionary alloc] init];
            int units = 0;
            for (NSString *uniformName in data.uniforms) {
                id value = [data.uniforms objectForKey:uniformName];
                GLenum type = [uniformTypes[uniformName] intValue];


                if (type == GL_SAMPLER_2D || type == GL_SAMPLER_CUBE) {
                    uniforms[uniformName] = [NSNumber numberWithInt:units++];
                    if ([value isEqual:[NSNull null]]) {
                        GLTexture *emptyTexture = [[GLTexture alloc] init];
                        [emptyTexture setPixels:nil];
                        textures[uniformName] = emptyTexture;
                    }
                    else {
                        NSString *type = [RCTConvert NSString:value[@"type"]];
                        if ([type isEqualToString:@"content"]) {
                            int id = [[RCTConvert NSNumber:value[@"id"]] intValue];
                            if (id >= [_contentTextures count]) {
                                [self resizeUniformContentTextures:id+1];
                            }
                            textures[uniformName] = _contentTextures[id];
                        }
                        else if ([type isEqualToString:@"fbo"]) {
                            NSNumber *id = [RCTConvert NSNumber:value[@"id"]];
                            GLFBO *fbo = [_bridge.rnglContext getFBO:id];
                            textures[uniformName] = fbo.color[0];
                        }
                        else if ([type isEqualToString:@"uri"]) {
                            NSString *src = srcResource(value);
                            if (!src) {
                                RCTLogError(@"texture uniform '%@': Invalid uri format '%@'", uniformName, value);
                            }

                            GLImage *image = images[src];
                            if (image == nil) {
                                image = prevImages[src];
                                if (image != nil)
                                    images[src] = image;
                            }
                            if (image == nil) {
                                __weak GLCanvas *weakSelf = self;
                                image = [[GLImage alloc] initWithBridge:_bridge withOnLoad:^{
                                    if (weakSelf) [weakSelf onImageLoad:src];
                                }];
                                image.src = src;
                                images[src] = image;
                            }
                            textures[uniformName] = [image getTexture];
                        }
                        else {
                            RCTLogError(@"texture uniform '%@': Unexpected type '%@'", uniformName, type);
                        }
                    }
                }
                else {
                    uniforms[uniformName] = value;
                }
            }

            int maxTextureUnits;
            glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &maxTextureUnits);
            if (units > maxTextureUnits) {
                RCTLogError(@"Maximum number of texture reach. got %i >= max %i", units, maxTextureUnits);
            }
            
            for (NSString *uniformName in shader.uniformTypes) {
                if (uniforms[uniformName] == nil) {
                    RCTLogError(@"All defined uniforms must be provided. Missing '%@'", uniformName);
                }
            }
            
            return [[GLRenderData alloc]
                    initWithShader:shader
                    withUniforms:uniforms
                    withTextures:textures
                    withWidth:(int)([width floatValue] * [pixelRatio floatValue])
                    withHeight:(int)([height floatValue] * [pixelRatio floatValue])
                    withFboId:fboId
                    withContextChildren:contextChildren
                    withChildren:children];
        };
        
        GLRenderData *res = traverseTree(_data);
        if (res != nil) {
            _renderData = traverseTree(_data);
            _images = images;
            for (NSString *src in diff([prevImages allKeys], [images allKeys])) {
                [_preloaded removeObject:src];
            }
            return true;
        }
        else {
            return false;
        }
    }
}



- (BOOL)haveRemainingToPreload
{
    for (id res in _imagesToPreload) {
        if (![_preloaded containsObject:srcResource(res)]) {
            return true;
        }
    }
    return false;
}

//// Draw

- (void)drawRect:(CGRect)rect
{
    self.layer.opaque = _opaque;

    if (_neverRendered) {
        _neverRendered = false;
        glClearColor(0.0, 0.0, 0.0, 0.0);
        glClear(GL_COLOR_BUFFER_BIT);
    }

    if (_needSync) {
        NSError *error;
        BOOL syncSuccessful = [self syncData:&error];
        BOOL errorCanBeRecovered = error==nil || (error.code != GLLinkingFailure && error.code != GLCompileFailure);
        if (!syncSuccessful && errorCanBeRecovered) {
            // something failed but is recoverable, retry in one tick
            [self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:NO];
        }
        else {
            _needSync = false;
        }
    }

    if ([self haveRemainingToPreload]) {
        return;
    }

    BOOL needsDeferredRendering = [_nbContentTextures intValue] > 0 && !_autoRedraw;
    if (needsDeferredRendering && !_deferredRendering) {
        _deferredRendering = true;
        [self performSelectorOnMainThread:@selector(syncContentData) withObject:nil waitUntilDone:NO];
    }
    else {
        _deferredRendering = false;
        [self render];
        if (!_captureScheduled && [_captureConfigs count] > 0) {
            _captureScheduled = true;
            [self performSelectorOnMainThread:@selector(capture) withObject:nil waitUntilDone:NO];
        }
    }
}


- (void)render
{
  if (!_renderData) return;
  
  CGFloat scale = RCTScreenScale();
  
  @autoreleasepool {
    void (^recDraw) (GLRenderData *renderData);
    __block __weak void (^weak_recDraw) (GLRenderData *renderData);
    weak_recDraw = recDraw = ^void(GLRenderData *renderData) {
        int w = renderData.width;
        int h = renderData.height;
      for (GLRenderData *child in renderData.contextChildren)
        weak_recDraw(child);
      
      for (GLRenderData *child in renderData.children)
        weak_recDraw(child);
      
      if (renderData.fboId == -1) {
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFBO);
        glViewport(0, 0, w, h);
      }
      else {
        GLFBO *fbo = [_bridge.rnglContext getFBO:[NSNumber numberWithInt:renderData.fboId]];
        [fbo setShapeWithWidth:w withHeight:h];
        [fbo bind];
      }
      
      [renderData.shader bind];
      
      for (NSString *uniformName in renderData.textures) {
        GLTexture *texture = renderData.textures[uniformName];
        int unit = [((NSNumber *)renderData.uniforms[uniformName]) intValue];
        [texture bind:unit];
      }
      
      for (NSString *uniformName in renderData.uniforms) {
        [renderData.shader setUniform:uniformName withValue:renderData.uniforms[uniformName]];
      }
      
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      glClearColor(0.0, 0.0, 0.0, 0.0);
      glClear(GL_COLOR_BUFFER_BIT);

      glDrawArrays(GL_TRIANGLES, 0, 6);
    };
    
    // DRAWING THE SCENE
    
    [self syncContentTextures];

    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &defaultFBO);
    glEnable(GL_BLEND);
    recDraw(_renderData);
    glDisable(GL_BLEND);
    glBindFramebuffer(GL_FRAMEBUFFER, defaultFBO);
    [[self openGLContext] flushBuffer];
  }
}

//// utility methods

- (void)onImageLoad:(NSString *)loaded
{
    [_preloaded addObject:loaded];
    int count = [self countPreloaded];
    int total = (int) [_imagesToPreload count];
    double progress = ((double) count) / ((double) total);
    [self dispatchOnProgress:progress withLoaded:count withTotal:total];
    _dirtyOnLoad = true;
    [self requestSyncData];
}

- (int)countPreloaded
{
  int nb = 0;
  for (id toload in _imagesToPreload) {
    if ([_preloaded containsObject:srcResource(toload)])
      nb++;
  }
  return nb;
}

- (void)resizeUniformContentTextures:(int)n
{
  [[self openGLContext] makeCurrentContext];
  int length = (int) [_contentTextures count];
  if (length == n) return;
  if (n < length) {
    _contentTextures = [_contentTextures subarrayWithRange:NSMakeRange(0, n)];
  }
  else {
    NSMutableArray *contentTextures = [[NSMutableArray alloc] initWithArray:_contentTextures];
    for (int i = (int) [_contentTextures count]; i < n; i++) {
      [contentTextures addObject:[[GLTexture alloc] init]];
    }
    _contentTextures = contentTextures;
  }
}

- (void)dispatchOnLoad
{
  [_bridge.eventDispatcher sendInputEventWithName:@"load" body:@{ @"target": self.reactTag }];
}

- (void)dispatchOnProgress: (double)progress withLoaded:(int)loaded withTotal:(int)total
{
  NSDictionary *event =
  @{
    @"target": self.reactTag,
    @"progress": @(progress),
    @"loaded": @(loaded),
    @"total": @(total) };
  [_bridge.eventDispatcher sendInputEventWithName:@"progress" body:event];
}

- (void)dispatchOnCapture: (NSString *)frame withId:(int)id
{
  NSDictionary *event = @{ @"target": self.reactTag, @"frame": frame, @"id":@(id) };
  // FIXME: using onChange is a hack before we use the new system to directly call callbacks. we will replace with: self.onCaptureNextFrame(...)
  [_bridge.eventDispatcher sendInputEventWithName:@"change" body:event];
}

@end
