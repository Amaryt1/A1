#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// ============================================================================
// 1. التجسير الآمن لدوال الكيشين (Dyld Interpose) - حفظ الجلسة واستقرار النظام
// ============================================================================
#define DYLD_INTERPOSE(_replacement,_replacee) \
    __attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
    __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };

static CFMutableDictionaryRef CleanKeychainQuery(CFDictionaryRef query) {
    if (!query) return NULL;
    CFMutableDictionaryRef mutableDict = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, query);
    if (mutableDict) {
        CFDictionaryRemoveValue(mutableDict, kSecAttrAccessGroup);
        CFDictionaryRemoveValue(mutableDict, kSecAttrAccessControl);
    }
    return mutableDict;
}

OSStatus my_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    CFMutableDictionaryRef cleaned = CleanKeychainQuery(attributes);
    OSStatus status = SecItemAdd(cleaned ? cleaned : attributes, result);
    if (cleaned) CFRelease(cleaned);
    return status;
}
DYLD_INTERPOSE(my_SecItemAdd, SecItemAdd);

OSStatus my_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    CFMutableDictionaryRef cleaned = CleanKeychainQuery(query);
    OSStatus status = SecItemCopyMatching(cleaned ? cleaned : query, result);
    if (cleaned) CFRelease(cleaned);
    return status;
}
DYLD_INTERPOSE(my_SecItemCopyMatching, SecItemCopyMatching);

OSStatus my_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    CFMutableDictionaryRef cleanedQuery = CleanKeychainQuery(query);
    CFMutableDictionaryRef cleanedAttrs = CleanKeychainQuery(attributesToUpdate);
    OSStatus status = SecItemUpdate(cleanedQuery ? cleanedQuery : query, cleanedAttrs ? cleanedAttrs : attributesToUpdate);
    if (cleanedQuery) CFRelease(cleanedQuery);
    if (cleanedAttrs) CFRelease(cleanedAttrs);
    return status;
}
DYLD_INTERPOSE(my_SecItemUpdate, SecItemUpdate);

OSStatus my_SecItemDelete(CFDictionaryRef query) {
    CFMutableDictionaryRef cleaned = CleanKeychainQuery(query);
    OSStatus status = SecItemDelete(cleaned ? cleaned : query);
    if (cleaned) CFRelease(cleaned);
    return status;
}
DYLD_INTERPOSE(my_SecItemDelete, SecItemDelete);

// ============================================================================
// 2. إعدادات المتخفي والميزات (Global Settings)
// ============================================================================
static BOOL gGhostStoryEnabled = YES; // التخفي في الستوري
static BOOL gGhostDMEnabled    = YES; // التخفي في المحادثات (عدم إرسال Seen)
static BOOL gViewOnceBypass    = YES; // تكرار مشاهدة الصور والفيديوهات المؤقتة

// ============================================================================
// 3. أدوات المساعدة ومستخرج الوسائط (Downloader & Audio Extractor)
// ============================================================================
static UIViewController *GetTopViewController(void) {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) { keyWindow = window; break; }
                }
            }
        }
    }
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) { topVC = topVC.presentedViewController; }
    return topVC;
}

static NSURL *ExtractVideoURLFromView(UIView *view) {
    if (!view) return nil;
    if ([view.layer isKindOfClass:[AVPlayerLayer class]]) {
        AVPlayerLayer *playerLayer = (AVPlayerLayer *)view.layer;
        AVPlayerItem *currentItem = playerLayer.player.currentItem;
        if ([currentItem.asset isKindOfClass:[AVURLAsset class]]) {
            return ((AVURLAsset *)currentItem.asset).URL;
        }
    }
    for (UIView *subview in view.subviews) {
        NSURL *url = ExtractVideoURLFromView(subview);
        if (url) return url;
    }
    return nil;
}

static void SaveMediaToAlbum(NSURL *mediaURL, BOOL isVideo) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:mediaURL];
        if (!data) return;

        NSString *ext = isVideo ? @"mp4" : @"jpg";
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ig_media.%@", ext]];
        [data writeToFile:tempPath atomically:YES];

        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            if (isVideo) {
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:tempPath]];
            } else {
                [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:tempPath]];
            }
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IGAMARYT"
                                                                               message:success ? @"تم التنزيل والحفظ في ألبوم الصور بنجاح! 💾" : @"فشل الحفظ، تحقق من الصلاحيات."
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
                [GetTopViewController() presentViewController:alert animated:YES completion:nil];
            });
        }];
    });
}

static void ExtractAndSaveAudio(NSURL *videoURL) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
    
    NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ig_audio.m4a"];
    [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    
    exportSession.outputURL = [NSURL fileURLWithPath:outputPath];
    exportSession.outputFileType = AVFileTypeAppleM4A;
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:outputPath]] applicationActivities:nil];
                [GetTopViewController() presentViewController:activityVC animated:YES completion:nil];
            } else {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IGAMARYT" message:@"فشل استخراج الصوت من المقطع." preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
                [GetTopViewController() presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

// ============================================================================
// 4. خيارات التحميل المتعددة (فيديو بدقات / صوت فقط / صور)
// ============================================================================
static void ShowDownloadOptions(NSURL *videoURL) {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"خيارات التحميل - IGAMARYT"
                                                                   message:@"اختر صيغة أو دقة التحميل المطلوبة:"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"🎥 تحميل الفيديو (أعلى دقة HQ)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        SaveMediaToAlbum(videoURL, YES);
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"🎵 استخراج الصوت فقط (Audio M4A)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        ExtractAndSaveAudio(videoURL);
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [GetTopViewController() presentViewController:sheet animated:YES completion:nil];
}

// ============================================================================
// 5. Swizzling - فتح الصور المؤقتة بدون حد والتخفي
// ============================================================================

// فتح وإعادة تشغيل الوسائط المؤقتة (View Once) لعدد لا نهائي
static BOOL (*orig_isExpired)(id self, SEL _cmd);
static BOOL my_isExpired(id self, SEL _cmd) {
    if (gViewOnceBypass) return NO; // منع تحول الصورة/الفيديو إلى منتهي
    return orig_isExpired(self, _cmd);
}

static BOOL (*orig_canReplay)(id self, SEL _cmd);
static BOOL my_canReplay(id self, SEL _cmd) {
    if (gViewOnceBypass) return YES; // السماح بإعادة التشغيل دائمًا
    return orig_canReplay(self, _cmd);
}

// التخفي في القراءة (DMs & Stories)
static void (*orig_markAsRead)(id self, SEL _cmd, id arg1);
static void my_markAsRead(id self, SEL _cmd, id arg1) {
    if (gGhostDMEnabled || gGhostStoryEnabled) return; // حجب إرسال إشعار القراءة
    orig_markAsRead(self, _cmd, arg1);
}

// ============================================================================
// 6. قائمة التحكم العائمة والتهيئة
// ============================================================================
static void ShowAMARYTMenu(void) {
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"🔥 IGAMARYT Control"
                                                                  message:@"التحكم في أدوات انستغرام:"
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *ghostStoryTxt = gGhostStoryEnabled ? @"👁️ التخفي في الستوري: [مفعل]" : @"👁️ التخفي في الستوري: [معطل]";
    [menu addAction:[UIAlertAction actionWithTitle:ghostStoryTxt style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        gGhostStoryEnabled = !gGhostStoryEnabled;
    }]];

    NSString *ghostDMTxt = gGhostDMEnabled ? @"💬 التخفي في المحادثات: [مفعل]" : @"💬 التخفي في المحادثات: [معطل]";
    [menu addAction:[UIAlertAction actionWithTitle:ghostDMTxt style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        gGhostDMEnabled = !gGhostDMEnabled;
    }]];

    NSString *viewOnceTxt = gViewOnceBypass ? @"♾️ تكرار وسائط (View-Once): [مفعل]" : @"♾️ تكرار وسائط (View-Once): [معطل]";
    [menu addAction:[UIAlertAction actionWithTitle:viewOnceTxt style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        gViewOnceBypass = !gViewOnceBypass;
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"⬇️ تحميل الوسائط الحالية / الريل" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSURL *vURL = ExtractVideoURLFromView([UIApplication sharedApplication].keyWindow);
        if (vURL) {
            ShowDownloadOptions(vURL);
        } else {
            UIAlertController *err = [UIAlertController alertControllerWithTitle:@"IGAMARYT" message:@"قم بفتح الريل أو الصورة المؤقتة أولاً ثم اضغط تحميل." preferredStyle:UIAlertControllerStyleAlert];
            [err addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
            [GetTopViewController() presentViewController:err animated:YES completion:nil];
        }
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]];
    [GetTopViewController() presentViewController:menu animated:YES completion:nil];
}

__attribute__((constructor))
static void initIGAMARYTPlugin(void) {
    // 1. Swizzling لوسائط View-Once
    Class visualMessageClass = NSClassFromString(@"IGDirectVisualMessage") ?: NSClassFromString(@"IGDirectVisualMedia");
    if (visualMessageClass) {
        Method m1 = class_getInstanceMethod(visualMessageClass, @selector(isExpired));
        if (m1) {
            orig_isExpired = (BOOL (*)(id, SEL))method_getImplementation(m1);
            method_setImplementation(m1, (IMP)my_isExpired);
        }
        Method m2 = class_getInstanceMethod(visualMessageClass, @selector(canReplay));
        if (m2) {
            orig_canReplay = (BOOL (*)(id, SEL))method_getImplementation(m2);
            method_setImplementation(m2, (IMP)my_canReplay);
        }
    }

    // 2. Swizzling للتخفي في السين (Seen Block)
    Class threadControllerClass = NSClassFromString(@"IGDirectThreadDataController") ?: NSClassFromString(@"IGStoryDataController");
    if (threadControllerClass) {
        SEL markSel = @selector(markAsRead:);
        Method mMark = class_getInstanceMethod(threadControllerClass, markSel);
        if (mMark) {
            orig_markAsRead = (void (*)(id, SEL, id))method_getImplementation(mMark);
            method_setImplementation(mMark, (IMP)my_markAsRead);
        }
    }

    // 3. تفعيل زر الإشعارات لإظهار لوحة التحكم عند هز الجهاز (Shake Gesture) أو الإقلاع
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IGAMARYT" message:@"تم تفعيل التخفي، وحفظ الصور المؤقتة، وأدوات التحميل بنجاح!\n(قم بهز الجهاز لعرض لوحة التحكم)" preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"لوحة التحكم" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    ShowAMARYTMenu();
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleCancel handler:nil]];
                [GetTopViewController() presentViewController:alert animated:YES completion:nil];
            });
        });
    }];
}

#pragma clang diagnostic pop
