<!--
# license: Licensed to the Apache Software Foundation (ASF) under one
#         or more contributor license agreements.  See the NOTICE file
#         distributed with this work for additional information
#         regarding copyright ownership.  The ASF licenses this file
#         to you under the Apache License, Version 2.0 (the
#         "License"); you may not use this file except in compliance
#         with the License.  You may obtain a copy of the License at
#
#           http://www.apache.org/licenses/LICENSE-2.0
#
#         Unless required by applicable law or agreed to in writing,
#         software distributed under the License is distributed on an
#         "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#         KIND, either express or implied.  See the License for the
#         specific language governing permissions and limitations
#         under the License.
-->


Cordova Alpha WKWebView Engine
======

This is a modified version of the Cordova WkWebView Engine plugin that includes a custom URL scheme, alpha-local:// for access to local asset files
stored in the device local file system. Assumes the requested file name uses the file:// protocol. 

This plugin can also display the contents of a file in a native modal file viewer that supports pdf, doc, xls, ppt and zip files.

To access local jpg image files add the prefix:   alpha-local://jpg?url= to the local jpg file name.

To access local png image files add the prefix:   alpha-local://png?url= to the local png file name.

To access local audio files add the prefix:   alpha-local://audio?url= to the local audio file name.

To access local video files, add the prefix:  alpha-local://video?url= to the local video file name.

To access local html files, add the prefix:  alpha-local://html?url= to the local html file name.

To display an image, pdf, xlsx, doc, ppt, text, csv, RTF, Pages, Keynote, Numbers, zip, audio, video or usdz local file in a Quick Look native iOS viewer (that supports pinch zoom and sharing options), add the prefix:  alpha-local://view?url= to the local pdf file name.

To display a directory of files that may include any of the Quick Look supported formats (listed above), add the prefix: alpha-local://viewdir?url=file:///pathToLocalFile/local/directory/.

Here's an example to the localFiles/project1 directory from a test app:  : alpha-local://viewdir?url=file:///var/mobile/Containers/Data/Application/1920522B-3AA6-4BAE-8007-5B4E8AEACC14/Library/NoCloud//localFiles/project1/

If the application was compiled with Xcode 11 (or greater) and the device is running iOS 13 (or greater), editing for images, movies and PDF files is supported. The edited file will overwrite the local file in this plugin version. It is up to the developer to upload the modified file if that is a requirement. The edited file can be shared via the standard iOS share menu. 

-----------

This plugin makes `Cordova` use the `WKWebView` component instead of the default `UIWebView` component, and is installable only on a system with the iOS 9.0 > SDK.

In iOS 9, Apple has fixed the [issue](http://www.openradar.me/18039024) present through iOS 8 where you cannot load locale files using file://, and must resort to using a local webserver. **However, you are still not able to use XHR from the file:// protocol without [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS) enabled on your server.**

Installation
-----------

This plugin needs cordova-ios >4.0.0.

To install the current release:

    cordova create wkwvtest my.project.id wkwvtest
    cd wkwvtest
    cordova platform add ios@4
    cordova plugin add https://github.com/remoorejr/cordova-plugin-alpha-wkwebview-engine.git

You also must have at least Xcode 7 (iOS 9 SDK) installed. Check your Xcode version by running:

    xcode-select --print-path

Required Permissions
-----------
WKWebView may not fully launch (the deviceready event may not fire) unless if the following is included in config.xml. This should already be installed by Cordova in your platform config.xml when the plugin is installed.

#### config.xml

```xml
<feature name="CDVWKWebViewEngine">
  <param name="ios-package" value="CDVWKWebViewEngine" />
</feature>

<preference name="CordovaWebViewEngine" value="CDVWKWebViewEngine" />
```

Notes
------
This plugin creates a shared `WKProcessPool` which ensures the cookie sharing happens correctly across `WKWebView` instances. `CDVWKProcessPoolFactory` class can be used to obtain the shared `WKProcessPool` instance if app creates `WKWebView` outside of this plugin.

On an iOS 8 system, Apache Cordova during runtime will switch to using the UIWebView engine instead of using this plugin. If you want to use WKWebView on both iOS 8 and iOS 9 platforms, you will have to resort to using a local webserver.

We have an [experimental plugin](https://github.com/apache/cordova-plugins/tree/wkwebview-engine-localhost) that does this. You would use that plugin instead of this one.

Application Transport Security (ATS) in iOS 9
-----------

Starting with [cordova-cli 5.4.0](https://www.npmjs.com/package/cordova), it will support automatic conversion of the [&lt;access&gt;](http://cordova.apache.org/docs/en/edge/guide/appdev/whitelist/index.html) tags in config.xml to Application Transport Security [ATS](https://developer.apple.com/library/prerelease/ios/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW33) directives.

Upgrade to at least version 5.4.0 of the cordova-cli to use this new functionality.

Enabling Navigation Gestures ("Swipe Navigation")
-----------

In order to allow swiping backwards and forwards in browser history like Safari does, you can set the following preference in your `config.xml`:

```xml
<preference name="AllowBackForwardNavigationGestures" value="true" />
```

You can also set this preference dynamically from JavaScript:

```js
window.WkWebView.allowsBackForwardNavigationGestures(true)
window.WkWebView.allowsBackForwardNavigationGestures(false)
```

Limitations
--------

If you are upgrading from UIWebView, please note the limitations of using WKWebView as outlined in our [issue tracker](https://issues.apache.org/jira/issues/?jql=project%20%3D%20CB%20AND%20labels%20%3D%20wkwebview-known-issues).

Apple Issues
-------

The `AllowInlineMediaPlayback` preference will not work because of this [Apple bug](http://openradar.appspot.com/radar?id=6673091526656000). This bug [has been fixed](https://issues.apache.org/jira/browse/CB-11452) in [iOS 10](https://twitter.com/shazron/status/745546355796389889).



Supported Platforms
-------------------

- iOS
