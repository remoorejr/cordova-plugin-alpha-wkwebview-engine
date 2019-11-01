//
//  QLPreviewItemCustom.h
//  Dir Viewer
//
//  Created by R.E. Moore Jr. on 10/31/19.
//

#ifndef QLPreviewItemCustom_h
#define QLPreviewItemCustom_h

#import <Foundation/Foundation.h>
#import <Quicklook/QuickLook.h>

@interface QLPreviewItemCustom : NSObject <QLPreviewItem>
    -(id) initWithTitle:(NSString*)title url:(NSURL*)url;
@end

#endif /* QLPreviewItemCustom_h */
