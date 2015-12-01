#import "GLCanvasManager.h"
#import "GLCanvas.h"
#import "RCTConvert+GLData.h"
#import "RCTLog.h"
#import <AppKit/AppKit.h>

@implementation GLCanvasManager

RCT_EXPORT_MODULE();

- (instancetype)init
{
  self = [super init];
  if (self) {
  }
  return self;
}

RCT_EXPORT_VIEW_PROPERTY(nbContentTextures, NSNumber);
RCT_EXPORT_VIEW_PROPERTY(opaque, BOOL);
RCT_EXPORT_VIEW_PROPERTY(autoRedraw, BOOL);
RCT_EXPORT_VIEW_PROPERTY(eventsThrough, BOOL);
RCT_EXPORT_VIEW_PROPERTY(visibleContent, BOOL);
RCT_EXPORT_VIEW_PROPERTY(captureNextFrameId, int);
RCT_EXPORT_VIEW_PROPERTY(data, GLData);
RCT_EXPORT_VIEW_PROPERTY(renderId, NSNumber);
RCT_EXPORT_VIEW_PROPERTY(imagesToPreload, NSArray);
RCT_EXPORT_VIEW_PROPERTY(onLoad, BOOL);
RCT_EXPORT_VIEW_PROPERTY(onProgress, BOOL);
RCT_EXPORT_VIEW_PROPERTY(onChange, BOOL);

/* TODO

 RCT_EXPORT_METHOD(capture:
 (nonnull NSNumber *)reactTag
 callback:(RCTResponseSenderBlock)callback)
 {
 
 UIView *view = [self.bridge.uiManager viewForReactTag:reactTag];
 if ([view isKindOfClass:[GLCanvas class]]) {
 [((GLCanvas*)view) capture: callback];
 }
 else {
 callback(@[@"view is not a GLCanvas"]);
 }
 }
 */

- (NSView *)view
{
  GLCanvas * v;
  v = [[GLCanvas alloc] initWithBridge:self.bridge];
  return v;
  
}

@end