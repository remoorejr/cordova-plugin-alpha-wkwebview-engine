/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

 /* Modified for use with Alpha Anywhere and the Alpha Anywhere Instant Update feature
    By: @remoorejr
    Date Last Revised: 03-05-2021
 
    Includes custom URL scheme handler for access to local device files
    Includes QuickLook for viewing local files
    03-05-2021: added support for SVG images
 */


#import "CDVWKWebViewEngine.h"
#import "CDVWKWebViewUIDelegate.h"
#import "CDVWKProcessPoolFactory.h"
#import <Cordova/NSDictionary+CordovaPreferences.h>

#import <objc/message.h>
#import <Quicklook/Quicklook.h>
#import "QLPreviewItemCustom.h"

#define CDV_BRIDGE_NAME @"cordova"
#define CDV_WKWEBVIEW_FILE_URL_LOAD_SELECTOR @"loadFileURL:allowingReadAccessToURL:"

@interface CDVWKWeakScriptMessageHandler : NSObject <WKScriptMessageHandler>

@property (nonatomic, weak, readonly) id<WKScriptMessageHandler>scriptMessageHandler;

- (instancetype)initWithScriptMessageHandler:(id<WKScriptMessageHandler>)scriptMessageHandler;

@end


#pragma mark - Custom URL Scheme Handler Class
@interface CustomUrlSchemeHandler : NSObject <WKURLSchemeHandler, QLPreviewControllerDataSource, QLPreviewControllerDelegate>

@property (nonatomic, strong) id <WKURLSchemeTask> task;
@property (nonatomic, strong) NSString *localFilePath;
@property (nonatomic, strong) NSArray  *fileList;
@property (nonatomic, strong) NSURL    *previewItemURL;
@property (nonatomic, assign) NSInteger itemCount;
@property (nonatomic, assign) BOOL showDir;


- (void) webView:(WKWebView *)webView startURLSchemeTask: (id <WKURLSchemeTask>)urlSchemeTask;
- (void) webView:(WKWebView *)webview stopURLSchemeTask : (id <WKURLSchemeTask>)urlSchemeTask;

@end

@implementation CustomUrlSchemeHandler

- (void) webView: (WKWebView *) webView startURLSchemeTask:(nonnull id <WKURLSchemeTask>) urlSchemeTask {
    NSLog(@"Start called for custom URL scheme handler for alpha-local://");
    NSURL *url = urlSchemeTask.request.URL;
    
    NSString *thisURL = url.absoluteString;
    
    // init properties
    _itemCount  = 1;
    _showDir = FALSE;
    _task = urlSchemeTask;
    
    NSString *jpgImageSignature = @"alpha-local://jpg?url=file://";
    NSString *pngImageSignature = @"alpha-local://png?url=file://";
    NSString *svgImageSignature = @"alpha-local://svg?url=file://";
    NSString *audioSignature =    @"alpha-local://audio?url=file://";
    NSString *videoSignature =    @"alpha-local://video?url=file://";
    NSString *htmlSignature =     @"alpha-local://html?url=file://";
    NSString *viewSignature =     @"alpha-local://view?url=file://";
    NSString *viewDirSignature =  @"alpha-local://viewdir?url=file://";

    //set defaults to handle jpg image
    NSString *thisSignature = jpgImageSignature;
    NSString *mimeType = @"image/jpg";
    
    BOOL showDocViewer = FALSE;
    
    if ([thisURL containsString:htmlSignature]) {
        thisSignature = htmlSignature;
        mimeType = @"text/html";
        showDocViewer = FALSE;
        
        if ([thisURL containsString:@"file://"]) {
            // determine/set local file path, strip filename and ext.
            NSString *requestedFileName = [thisURL lastPathComponent];
            _localFilePath = [thisURL stringByReplacingOccurrencesOfString:requestedFileName withString:@""];
            _localFilePath = [_localFilePath stringByReplacingOccurrencesOfString:thisSignature withString:@""];
        }
     } else if  ([thisURL containsString:jpgImageSignature]) {
        thisSignature = jpgImageSignature;
        mimeType = @"image/jpg";
        showDocViewer = FALSE;

    } else if  ([thisURL containsString:pngImageSignature]) {
        thisSignature = pngImageSignature;
        mimeType = @"image/png";
        showDocViewer = FALSE;
        
    } else if  ([thisURL containsString:svgImageSignature]) {
        thisSignature = svgImageSignature;
        mimeType = @"image/svg+xml";
        showDocViewer = FALSE;
        
    } else if ([thisURL containsString:audioSignature]) {
        thisSignature = audioSignature;
        NSString *ext = [thisURL pathExtension];

         if ([[ext lowercaseString] isEqualToString:@"mp3"]) {
            mimeType = @"audio/mpeg";
        } else {
            mimeType = @"audio/mp4";
        }
        showDocViewer = FALSE;

    } else if ([thisURL containsString:videoSignature]) {
        thisSignature = videoSignature;
        mimeType = @"video/mp4";
        showDocViewer = FALSE;

    } else if ([thisURL containsString:viewSignature]) {
        thisSignature = viewSignature;
         mimeType = @"application/octet-stream";
        showDocViewer = TRUE;
        
    } else if ([thisURL containsString:viewDirSignature]) {
        thisSignature = viewDirSignature;
         mimeType = @"application/octet-stream";
        showDocViewer = TRUE;
    
    } else if ([thisURL hasPrefix:@"alpha-local://"]) {
        // relative URL's
        if ([thisURL containsString:@".html"]) {
            mimeType = @"text/html";

        } else if ([thisURL containsString:@".js"]) {
            mimeType = @"text/javascript";

        } else if ([thisURL containsString:@".css"]) {
            mimeType = @"text/css";
        } else {
            mimeType = @"text/plain";
            NSLog(@"*** Unhandled file type, %@, mimeType: %@",thisURL,mimeType);
        }
    } else {
         NSLog(@"*** File signature not recognized,  %@, mimeType: %@",thisURL,mimeType);
    }
     
    thisURL = [thisURL stringByReplacingOccurrencesOfString:thisSignature withString:@""];
    
    if (showDocViewer) {
        NSLog(@"Local file url -> %@",thisURL);
        
        if (thisSignature == viewSignature) {
           
            _showDir = FALSE;
            NSURL *docURL=  [NSURL fileURLWithPath:thisURL];
        
            NSFileManager *fileManager = [NSFileManager defaultManager];
            BOOL fileExists = [fileManager fileExistsAtPath: thisURL];
        
            if (fileExists) {
                
                _itemCount = 1;
                _previewItemURL = [docURL copy];
            
                QLPreviewController *previewController = [[QLPreviewController alloc] init];
                previewController.dataSource = self;
                previewController.delegate = self;
                previewController.currentPreviewItemIndex = 0;
                                       
                UIViewController* root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
                [root presentViewController:previewController animated:YES completion:nil];
                
                // complete but don't send anything back
                // the file was displayed by QuickLook
            
                NSString *str =@"";
                NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];

                NSURLResponse *response;
                [response setValue: docURL forKey:@"url"];
                [response setValue: mimeType forKey:@"mimeType"];
                [response setValue:@"-1" forKey:@"expectedContentLength"];
                [response setValue:nil forKey:@"textEncodingName"];
                [_task didReceiveResponse: response];
                [_task didReceiveData: data];
                [_task didFinish];
            }
        } else {
            // showdir
            _showDir = TRUE;
             NSURL *docURL=  [NSURL fileURLWithPath:thisURL];
            
            NSLog(@"This URL->> %@",thisURL);
            NSLog(@"Doc URL ->> %@",docURL);
            
             NSFileManager *fileManager = [NSFileManager defaultManager];
             NSArray *listOfFiles = [fileManager contentsOfDirectoryAtPath:thisURL error:NULL];
            _itemCount = [listOfFiles count];
            
            // NSArray *directoryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
            
            NSString *fileName;
            NSString *filePath = thisURL;
           
            NSString *fullFileName;
            NSMutableArray *filesWithPath = [[NSMutableArray alloc] init];
            
            for (int i=0; i<_itemCount; i++) {
                fileName = [listOfFiles objectAtIndex:i];
                fullFileName = [NSString stringWithFormat:@"%@%@", filePath,fileName];
                [filesWithPath addObject:fullFileName];
                
                // set global
                _fileList = [filesWithPath copy];
            }
           
            if (_itemCount > 0) {
                QLPreviewController *previewController = [[QLPreviewController alloc] init];
                previewController.dataSource = self;
                previewController.delegate = self;
                previewController.currentPreviewItemIndex = 0;
                        
                UIViewController* root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
                [root presentViewController:previewController animated:YES completion:nil];
                     
                // complete but don't send anything back
                // the file was displayed by QuickLook
                           
                NSString *str =@"";
                NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];

                NSURLResponse *response;
                [response setValue: docURL forKey:@"url"];
                [response setValue: mimeType forKey:@"mimeType"];
                [response setValue:@"-1" forKey:@"expectedContentLength"];
                [response setValue:nil forKey:@"textEncodingName"];
                [_task didReceiveResponse: response];
                [_task didReceiveData: data];
                [_task didFinish];
            }
        }
    } else {
        // handle all css, JavaScript files, etc. requested by root html document
        if ([thisURL containsString:@"alpha-local://html"]) {
            thisURL = [thisURL stringByReplacingOccurrencesOfString:@"alpha-local://html" withString:_localFilePath];
        }
        
        /*
           A random query string may have been added to some css files to force a non-cached read.
           File read will fail if the query string is included.
           Strip query string if present.
        */
        
        NSURL *revisedURL = [NSURL URLWithString:thisURL];
        NSString *urlQuery = revisedURL.query;

        if (urlQuery != nil) {
            thisURL = [revisedURL.absoluteString stringByReplacingOccurrencesOfString:revisedURL.query withString:@""];
            thisURL = [thisURL stringByReplacingOccurrencesOfString:@"?" withString:@""];
        }
        
        NSLog(@"Local file url -> %@",thisURL);
        
        NSURL *modifiedURL = [NSURL URLWithString:thisURL];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL fileExists = [fileManager fileExistsAtPath: thisURL];
        if (fileExists) {
            
            // Read file
            NSData *data = [NSData dataWithContentsOfFile:thisURL];
            NSUInteger count = data.length;
        
            // Send data back
            // was -> NSURLResponse *response = [[NSURLResponse alloc] initWithURL:modifiedURL MIMEType:mimeType expectedContentLength:count textEncodingName:@""];

             NSDictionary *headerDictionary = @{
                @"Content-Length" : [NSString stringWithFormat:@"%lu", (unsigned long)count],
                @"Content-Type" : mimeType,
                @"Access-Control-Allow-Origin" : @"*"
            };

            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:modifiedURL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headerDictionary];

            [_task didReceiveResponse: response];
            [_task didReceiveData: data];
            [_task didFinish];
        } else {
             NSLog(@"** File not found -> %@",thisURL);
            NSError *error = [NSError errorWithDomain: NSCocoaErrorDomain code:4 userInfo:nil];
            [_task didFailWithError:error];
        }
    }
}
   
#pragma mark - QLPreviewControllerDataSource Methods
- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)previewController
    {
        return _itemCount;
    }

- (id <QLPreviewItem>) previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index
    {
        if (_showDir) {
            NSLog(@"Index-> %lo filename -> %@",index,[_fileList objectAtIndex:index]);
            NSURL *thisURL = [NSURL fileURLWithPath:[_fileList objectAtIndex:index]];
            
             //below used to add a custom title, experimental 
            /*
             
            NSString *title = [[NSString alloc] initWithFormat: @"file ->%lo",index];
            QLPreviewItemCustom *customPreviewObj =[[QLPreviewItemCustom alloc] initWithTitle:title url:thisURL];
            return customPreviewObj;
             
            */
            return thisURL;
        } else {
            // show single file
            NSURL *fileURL = nil;
            fileURL = _previewItemURL;
            return fileURL;
        }
    }

#pragma mark - QLPreviewControllerDelegate Methods

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000

    - (QLPreviewItemEditingMode)  previewController:(QLPreviewController *)controller editingModeForPreviewItem:(nonnull id<QLPreviewItem>)previewItem API_AVAILABLE(ios(13.0)) {
        return QLPreviewItemEditingModeUpdateContents;
    }

#endif   


#pragma mark - QLPreviewItem Methods

- (void) webView: (WKWebView *) webView stopURLSchemeTask:(nonnull id <WKURLSchemeTask>)urlSchemeTask {
    NSLog(@"Stop called for custom URL scheme handler for alpha-local://");
    _task = nil;
}


@end





@interface CDVWKWebViewEngine ()

@property (nonatomic, strong, readwrite) UIView* engineWebView;
@property (nonatomic, strong, readwrite) id <WKUIDelegate> uiDelegate;
@property (nonatomic, strong, readwrite) id<WKURLSchemeHandler> urlHandler;
@property (nonatomic, weak) id <WKScriptMessageHandler> weakScriptMessageHandler;

@end

// see forwardingTargetForSelector: selector comment for the reason for this pragma
#pragma clang diagnostic ignored "-Wprotocol"

@implementation CDVWKWebViewEngine

@synthesize engineWebView = _engineWebView;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super init];
    if (self) {
        if (NSClassFromString(@"WKWebView") == nil) {
            return nil;
        }

        self.engineWebView = [[WKWebView alloc] initWithFrame:frame];
    }

    return self;
}

- (WKWebViewConfiguration*) createConfigurationFromSettings:(NSDictionary*)settings
{
    WKWebViewConfiguration* configuration = [[WKWebViewConfiguration alloc] init];
    configuration.processPool = [[CDVWKProcessPoolFactory sharedFactory] sharedProcessPool];
    
    if (settings == nil) {
        return configuration;
    }

    configuration.allowsInlineMediaPlayback = [settings cordovaBoolSettingForKey:@"AllowInlineMediaPlayback" defaultValue:NO];
    configuration.mediaTypesRequiringUserActionForPlayback = [settings cordovaBoolSettingForKey:@"MediaPlaybackRequiresUserAction" defaultValue:YES];
    configuration.suppressesIncrementalRendering = [settings cordovaBoolSettingForKey:@"SuppressesIncrementalRendering" defaultValue:NO];
    configuration.allowsAirPlayForMediaPlayback = [settings cordovaBoolSettingForKey:@"MediaPlaybackAllowsAirPlay" defaultValue:YES];
    
    return configuration;
}


- (void)pluginInitialize
{
    // viewController would be available now. we attempt to set all possible delegates to it, by default
    NSDictionary* settings = self.commandDelegate.settings;

    self.uiDelegate = [[CDVWKWebViewUIDelegate alloc] initWithTitle:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]];
    
    // instantiate custom URL scheme handler
    CustomUrlSchemeHandler *myCustomUrlSchemeHandler;
    myCustomUrlSchemeHandler = [[CustomUrlSchemeHandler alloc] init];

    CDVWKWeakScriptMessageHandler *weakScriptMessageHandler = [[CDVWKWeakScriptMessageHandler alloc] initWithScriptMessageHandler:self];

    WKUserContentController* userContentController = [[WKUserContentController alloc] init];
    [userContentController addScriptMessageHandler:weakScriptMessageHandler name:CDV_BRIDGE_NAME];

    WKWebViewConfiguration* configuration = [self createConfigurationFromSettings:settings];
    configuration.userContentController = userContentController;

    //  set configuartion for persistent data store
    // configuration.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    
    // set configuation for custom URL scheme handler alpha-local
    [configuration setURLSchemeHandler:myCustomUrlSchemeHandler forURLScheme:@"alpha-local"];

    // re-create WKWebView, since we need to update configuration
    WKWebView* wkWebView = [[WKWebView alloc] initWithFrame:self.engineWebView.frame configuration:configuration];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 11.0, *)) {
        [wkWebView.scrollView setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
    }
#endif

    wkWebView.UIDelegate = self.uiDelegate;
    self.engineWebView = wkWebView;

    if (IsAtLeastiOSVersion(@"9.0") && [self.viewController isKindOfClass:[CDVViewController class]]) {
        wkWebView.customUserAgent = ((CDVViewController*) self.viewController).userAgent;
    }
   
    if ([self.viewController conformsToProtocol:@protocol(WKUIDelegate)]) {
        wkWebView.UIDelegate = (id <WKUIDelegate>)self.viewController;
    }

    if ([self.viewController conformsToProtocol:@protocol(WKNavigationDelegate)]) {
        wkWebView.navigationDelegate = (id <WKNavigationDelegate>)self.viewController;
    } else {
        wkWebView.navigationDelegate = (id <WKNavigationDelegate>)self;
    }
    
    if ([self.viewController conformsToProtocol:@protocol(WKScriptMessageHandler)]) {
        [wkWebView.configuration.userContentController addScriptMessageHandler:(id < WKScriptMessageHandler >)self.viewController name:CDV_BRIDGE_NAME];
    }

    [self updateSettings:settings];

    // check if content thread has died on resume
    NSLog(@"%@", @"CDVWKWebViewEngine will reload WKWebView if required on resume");
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(onAppWillEnterForeground:)
               name:UIApplicationWillEnterForegroundNotification object:nil];

    NSLog(@"Using WKWebView");

    [self addURLObserver];
}

- (void)onReset {
    [self addURLObserver];
}

static void * KVOContext = &KVOContext;

- (void)addURLObserver {
    if(!IsAtLeastiOSVersion(@"9.0")){
        [self.webView addObserver:self forKeyPath:@"URL" options:0 context:KVOContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if (context == KVOContext) {
        if (object == [self webView] && [keyPath isEqualToString: @"URL"] && [object valueForKeyPath:keyPath] == nil){
            NSLog(@"URL is nil. Reloading WKWebView");
            [(WKWebView*)_engineWebView reload];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void) onAppWillEnterForeground:(NSNotification*)notification {
    if ([self shouldReloadWebView]) {
        NSLog(@"%@", @"CDVWKWebViewEngine reloading!");
        [(WKWebView*)_engineWebView reload];
    }
}

- (BOOL)shouldReloadWebView
{
    WKWebView* wkWebView = (WKWebView*)_engineWebView;
    return [self shouldReloadWebView:wkWebView.URL title:wkWebView.title];
}

- (BOOL)shouldReloadWebView:(NSURL*)location title:(NSString*)title
{
    BOOL title_is_nil = (title == nil);
    BOOL location_is_blank = [[location absoluteString] isEqualToString:@"about:blank"];

    BOOL reload = (title_is_nil || location_is_blank);

#ifdef DEBUG
    NSLog(@"%@", @"CDVWKWebViewEngine shouldReloadWebView::");
    NSLog(@"CDVWKWebViewEngine shouldReloadWebView title: %@", title);
    NSLog(@"CDVWKWebViewEngine shouldReloadWebView location: %@", [location absoluteString]);
    NSLog(@"CDVWKWebViewEngine shouldReloadWebView reload: %u", reload);
#endif

    return reload;
}

- (id)loadRequest:(NSURLRequest*)request
{
    if ([self canLoadRequest:request]) { // can load, differentiate between file urls and other schemes
        if (request.URL.fileURL) {
            SEL wk_sel = NSSelectorFromString(CDV_WKWEBVIEW_FILE_URL_LOAD_SELECTOR);
            NSURL* readAccessUrl = [request.URL URLByDeletingLastPathComponent];
            return ((id (*)(id, SEL, id, id))objc_msgSend)(_engineWebView, wk_sel, request.URL, readAccessUrl);
        } else {
            return [(WKWebView*)_engineWebView loadRequest:request];
        }
    } else { // can't load, print out error
        NSString* errorHtml = [NSString stringWithFormat:
                               @"<!doctype html>"
                               @"<title>Error</title>"
                               @"<div style='font-size:2em'>"
                               @"   <p>The WebView engine '%@' is unable to load the request: %@</p>"
                               @"   <p>Most likely the cause of the error is that the loading of file urls is not supported in iOS %@.</p>"
                               @"</div>",
                               NSStringFromClass([self class]),
                               [request.URL description],
                               [[UIDevice currentDevice] systemVersion]
                               ];
        return [self loadHTMLString:errorHtml baseURL:nil];
    }
}

- (id)loadHTMLString:(NSString*)string baseURL:(NSURL*)baseURL
{
    return [(WKWebView*)_engineWebView loadHTMLString:string baseURL:baseURL];
}

- (NSURL*) URL
{
    return [(WKWebView*)_engineWebView URL];
}

- (BOOL) canLoadRequest:(NSURLRequest*)request
{
    // See: https://issues.apache.org/jira/browse/CB-9636
    SEL wk_sel = NSSelectorFromString(CDV_WKWEBVIEW_FILE_URL_LOAD_SELECTOR);

    // if it's a file URL, check whether WKWebView has the selector (which is in iOS 9 and up only)
    if (request.URL.fileURL) {
        return [_engineWebView respondsToSelector:wk_sel];
    } else {
        return YES;
    }
}

- (void)updateSettings:(NSDictionary*)settings
{
    WKWebView* wkWebView = (WKWebView*)_engineWebView;

    wkWebView.configuration.preferences.minimumFontSize = [settings cordovaFloatSettingForKey:@"MinimumFontSize" defaultValue:0.0];

    /*
     wkWebView.configuration.preferences.javaScriptEnabled = [settings cordovaBoolSettingForKey:@"JavaScriptEnabled" default:YES];
     wkWebView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = [settings cordovaBoolSettingForKey:@"JavaScriptCanOpenWindowsAutomatically" default:NO];
     */

    // By default, DisallowOverscroll is false (thus bounce is allowed)
    BOOL bounceAllowed = !([settings cordovaBoolSettingForKey:@"DisallowOverscroll" defaultValue:NO]);

    // prevent webView from bouncing
    if (!bounceAllowed) {
        if ([wkWebView respondsToSelector:@selector(scrollView)]) {
            ((UIScrollView*)[wkWebView scrollView]).bounces = NO;
        } else {
            for (id subview in wkWebView.subviews) {
                if ([[subview class] isSubclassOfClass:[UIScrollView class]]) {
                    ((UIScrollView*)subview).bounces = NO;
                }
            }
        }
    }

    NSString* decelerationSetting = [settings cordovaSettingForKey:@"WKWebViewDecelerationSpeed"];
    if (!decelerationSetting) {
        // Fallback to the UIWebView-named preference
        decelerationSetting = [settings cordovaSettingForKey:@"UIWebViewDecelerationSpeed"];
    }

    if (![@"fast" isEqualToString:decelerationSetting]) {
        [wkWebView.scrollView setDecelerationRate:UIScrollViewDecelerationRateNormal];
    } else {
        [wkWebView.scrollView setDecelerationRate:UIScrollViewDecelerationRateFast];
    }

    wkWebView.allowsBackForwardNavigationGestures = [settings cordovaBoolSettingForKey:@"AllowBackForwardNavigationGestures" defaultValue:NO];
}

- (void)updateWithInfo:(NSDictionary*)info
{
    NSDictionary* scriptMessageHandlers = [info objectForKey:kCDVWebViewEngineScriptMessageHandlers];
    NSDictionary* settings = [info objectForKey:kCDVWebViewEngineWebViewPreferences];
    id navigationDelegate = [info objectForKey:kCDVWebViewEngineWKNavigationDelegate];
    id uiDelegate = [info objectForKey:kCDVWebViewEngineWKUIDelegate];

    WKWebView* wkWebView = (WKWebView*)_engineWebView;

    if (scriptMessageHandlers && [scriptMessageHandlers isKindOfClass:[NSDictionary class]]) {
        NSArray* allKeys = [scriptMessageHandlers allKeys];

        for (NSString* key in allKeys) {
            id object = [scriptMessageHandlers objectForKey:key];
            if ([object conformsToProtocol:@protocol(WKScriptMessageHandler)]) {
                [wkWebView.configuration.userContentController addScriptMessageHandler:object name:key];
            }
        }
    }

    if (navigationDelegate && [navigationDelegate conformsToProtocol:@protocol(WKNavigationDelegate)]) {
        wkWebView.navigationDelegate = navigationDelegate;
    }

    if (uiDelegate && [uiDelegate conformsToProtocol:@protocol(WKUIDelegate)]) {
        wkWebView.UIDelegate = uiDelegate;
    }

    if (settings && [settings isKindOfClass:[NSDictionary class]]) {
        [self updateSettings:settings];
    }
}

// This forwards the methods that are in the header that are not implemented here.
// Both WKWebView and UIWebView implement the below:
//     loadHTMLString:baseURL:
//     loadRequest:
- (id)forwardingTargetForSelector:(SEL)aSelector
{
    return _engineWebView;
}

- (UIView*)webView
{
    return self.engineWebView;
}

#pragma mark WKScriptMessageHandler implementation

- (void)userContentController:(WKUserContentController*)userContentController didReceiveScriptMessage:(WKScriptMessage*)message
{
    if (![message.name isEqualToString:CDV_BRIDGE_NAME]) {
        return;
    }

    CDVViewController* vc = (CDVViewController*)self.viewController;

    NSArray* jsonEntry = message.body; // NSString:callbackId, NSString:service, NSString:action, NSArray:args
    CDVInvokedUrlCommand* command = [CDVInvokedUrlCommand commandFromJson:jsonEntry];
    CDV_EXEC_LOG(@"Exec(%@): Calling %@.%@", command.callbackId, command.className, command.methodName);

    if (![vc.commandQueue execute:command]) {
#ifdef DEBUG
        NSError* error = nil;
        NSString* commandJson = nil;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:jsonEntry
                                                           options:0
                                                             error:&error];

        if (error == nil) {
            commandJson = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }

            static NSUInteger maxLogLength = 1024;
            NSString* commandString = ([commandJson length] > maxLogLength) ?
                [NSString stringWithFormat : @"%@[...]", [commandJson substringToIndex:maxLogLength]] :
                commandJson;

            NSLog(@"FAILED pluginJSON = %@", commandString);
#endif
    }
}

#pragma mark WKNavigationDelegate implementation

- (void)webView:(WKWebView*)webView didStartProvisionalNavigation:(WKNavigation*)navigation
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginResetNotification object:webView]];
}

- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)navigation
{
    CDVViewController* vc = (CDVViewController*)self.viewController;
    [CDVUserAgentUtil releaseLock:vc.userAgentLockToken];

    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPageDidLoadNotification object:webView]];
}

- (void)webView:(WKWebView*)theWebView didFailProvisionalNavigation:(WKNavigation*)navigation withError:(NSError*)error
{
    [self webView:theWebView didFailNavigation:navigation withError:error];
}

- (void)webView:(WKWebView*)theWebView didFailNavigation:(WKNavigation*)navigation withError:(NSError*)error
{
    CDVViewController* vc = (CDVViewController*)self.viewController;
    [CDVUserAgentUtil releaseLock:vc.userAgentLockToken];

    NSString* message = [NSString stringWithFormat:@"Failed to load webpage with error: %@", [error localizedDescription]];
    NSLog(@"%@", message);

    NSURL* errorUrl = vc.errorURL;
    if (errorUrl) {
        NSCharacterSet *Cset = NSCharacterSet.URLPathAllowedCharacterSet;
        
        errorUrl = [NSURL URLWithString:[NSString stringWithFormat:@"?error=%@", [message stringByAddingPercentEncodingWithAllowedCharacters:Cset]] relativeToURL:errorUrl];
        NSLog(@"%@", [errorUrl absoluteString]);
        [theWebView loadRequest:[NSURLRequest requestWithURL:errorUrl]];
    }
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView
{
    [webView reload];
}

- (BOOL)defaultResourcePolicyForURL:(NSURL*)url
{
    // all file:// urls are allowed
    if ([url isFileURL]) {
        return YES;
    }

    return NO;
}

- (void) webView: (WKWebView *) webView decidePolicyForNavigationAction: (WKNavigationAction*) navigationAction decisionHandler: (void (^)(WKNavigationActionPolicy)) decisionHandler
{
    NSURL* url = [navigationAction.request URL];
    CDVViewController* vc = (CDVViewController*)self.viewController;

    /*
     * Give plugins the chance to handle the url
     */
    BOOL anyPluginsResponded = NO;
    BOOL shouldAllowRequest = NO;

    for (NSString* pluginName in vc.pluginObjects) {
        CDVPlugin* plugin = [vc.pluginObjects objectForKey:pluginName];
        SEL selector = NSSelectorFromString(@"shouldOverrideLoadWithRequest:navigationType:");
        if ([plugin respondsToSelector:selector]) {
            anyPluginsResponded = YES;
            // https://issues.apache.org/jira/browse/CB-12497
            int navType = (int)navigationAction.navigationType;
            if (WKNavigationTypeOther == navigationAction.navigationType) {
                navType = (int)UIWebViewNavigationTypeOther;
            }
            shouldAllowRequest = (((BOOL (*)(id, SEL, id, int))objc_msgSend)(plugin, selector, navigationAction.request, navType));
            if (!shouldAllowRequest) {
                break;
            }
        }
    }

    if (anyPluginsResponded) {
        return decisionHandler(shouldAllowRequest);
    }

    /*
     * Handle all other types of urls (tel:, sms:), and requests to load a url in the main webview.
     */
    BOOL shouldAllowNavigation = [self defaultResourcePolicyForURL:url];
    if (shouldAllowNavigation) {
        return decisionHandler(YES);
    } else {
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginHandleOpenURLNotification object:url]];
    }

    return decisionHandler(NO);
}


#pragma mark - Plugin interface

- (void)allowsBackForwardNavigationGestures:(CDVInvokedUrlCommand*)command;
{
    id value = [command argumentAtIndex:0];
    if (!([value isKindOfClass:[NSNumber class]])) {
        value = [NSNumber numberWithBool:NO];
    }

    WKWebView* wkWebView = (WKWebView*)_engineWebView;
    wkWebView.allowsBackForwardNavigationGestures = [value boolValue];
}

@end

#pragma mark - CDVWKWeakScriptMessageHandler

@implementation CDVWKWeakScriptMessageHandler

- (instancetype)initWithScriptMessageHandler:(id<WKScriptMessageHandler>)scriptMessageHandler
{
    self = [super init];
    if (self) {
        _scriptMessageHandler = scriptMessageHandler;
    }
    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    [self.scriptMessageHandler userContentController:userContentController didReceiveScriptMessage:message];
}

@end



