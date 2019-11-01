//
//  QLPreviewItemCustom.m
//  Dir Viewer
//
//  Created by R.E. Moore Jr. on 10/21/19.
//

#import "QLPreviewItemCustom.h"


@implementation QLPreviewItemCustom
@synthesize previewItemTitle = _previewItemTitle;
@synthesize previewItemURL =  _previewItemURL;

-(id) initWithTitle:(NSString *)title url:(NSURL *)url
{
    self = [super init];
    if (self != nil) {
        _previewItemTitle = title;
        _previewItemURL = url;
    }
    return self;
}


@end
