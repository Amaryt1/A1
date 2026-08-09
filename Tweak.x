#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <substrate.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// ============================================================================
// 1. إصلاح الكيشين (Keychain Fix) - يعمل بأمان في بداية التحميل
// ============================================================================

static OSStatus (*orig_SecItemAdd)(CFDictionaryRef attributes, CFTypeRef *result);
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result);
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef query, CFDictionaryRef attributesToUpdate);
static OSStatus (*orig_SecItemDelete)(CFDictionaryRef query);

static CFMutableDictionaryRef CleanKeychainQuery(CFDictionaryRef query) {
    if (!query) return NULL;
    CFMutableDictionaryRef mutableDict = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, query);
    CFDictionaryRemoveValue(mutableDict, kSecAttrAccessGroup);
    return mutableDict;
}

OSStatus hooked_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    CFMutableDictionaryRef cleaned = CleanKeychainQuery(attributes);
    OSStatus status = orig_SecItemAdd(cleaned, result);
    if (cleaned) CFRelease(cleaned);
    return status;
}

OSStatus hooked_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    CFMutableDictionaryRef cleaned = CleanKeychainQuery(query);
    OSStatus status = orig_SecItemCopyMatching(cleaned, result);
    if (cleaned) CFRelease(cleaned);
    return status;
}

OSStatus hooked_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    CFMutableDictionaryRef cleanedQuery = CleanKeychainQuery(query);
    OSStatus status = orig_SecItemUpdate(cleanedQuery, attributesToUpdate);
    if (cleanedQuery) CFRelease(cleanedQuery);
    return status;
}

OSStatus hooked_SecItemDelete(CFDictionaryRef query) {
    CFMutableDictionaryRef cleaned = CleanKeychainQuery(query);
    OSStatus status = orig_SecItemDelete(cleaned);
    if (cleaned) CFRelease(cleaned);
    return status;
}

// ============================================================================
// 2. دالة جلب الواجهة وعرض النافذة المنبثقة
// ============================================================================

static UIViewController *GetTopViewController(void) {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
            }
        }
    }
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

void ShowWelcomePopup(void) {
    UIViewController *topVC = GetTopViewController();
    if (!topVC) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AMARYT Tools"
                                                                   message:@"\nتم تفعيل الأدوات وإصلاح حفظ تسجيل الدخول بنجاح!"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    NSURL *imageURL = [NSURL URLWithString:@"https://i.ibb.co/nNR6pDdN/4-B524707-0-AB6-47-E7-984-F-1-C5661-B4-F776.jpg"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:imageURL];
        if (data) {
            UIImage *image = [UIImage imageWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{
                UIViewController *imageVC = [[UIViewController alloc] init];
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                imageView.contentMode = UIViewContentModeScaleAspectFit;
                imageView.clipsToBounds = YES;
                imageVC.view = imageView;
                
                [imageVC.view.heightAnchor constraintEqualToConstant:150].active = YES;
                [alert setValue:imageVC forKey:@"contentViewController"];
            });
        }
    });

    [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
    [topVC presentViewController:alert animated:YES completion:nil];
}

// ============================================================================
// 3. هوك إقلاع التطبيق ومميزات الفيسبوك الآمنة
// ============================================================================

// عرض النافذة المنبثقة فقط بعد اكتمال إقلاع التطبيق ونشاطه
%hook UIApplication
- (void)applicationDidBecomeActive:(id)application {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ShowWelcomePopup();
        });
    });
}
%end

// تجميع هوكات الفيسبوك لحمايتها من الانهيار عند عدم وجود الكلاس
%group FacebookHooks

%hook FBMemFeedItem
- (BOOL)isSponsored { return NO; }
- (BOOL)isSuggested { return NO; }
%end

%hook FBPickerPeopleYouMayKnowFeedUnit
- (id)init { return nil; }
%end

%hook FBReelsFeedUnit
- (id)init { return nil; }
%end

%hook FBStoryViewerViewController
- (void)markStoryAsRead:(id)arg1 { }
%end

%hook FBLikeButton
- (void)handleTap:(id)sender {
    UIViewController *topVC = GetTopViewController();
    if (!topVC) {
        %orig;
        return;
    }

    UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"تأكيد الإعجاب"
                                                                          message:@"هل تريد بالتأكيد وضع إعجاب على هذا المنشور؟"
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    
    [confirmAlert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [confirmAlert addAction:[UIAlertAction actionWithTitle:@"إعجاب" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        %orig;
    }]];
    
    [topVC presentViewController:confirmAlert animated:YES completion:nil];
}
%end

%end

// ============================================================================
// 4. تهيئة التويك الآمنة عند الإقلاع (%ctor)
// ============================================================================

%ctor {
    // 1. ربط دوال الكيشين لمنع خروج الحساب (آمن جداً عند الإقلاع)
    MSHookFunction((void *)SecItemAdd, (void *)hooked_SecItemAdd, (void **)&orig_SecItemAdd);
    MSHookFunction((void *)SecItemCopyMatching, (void *)hooked_SecItemCopyMatching, (void **)&orig_SecItemCopyMatching);
    MSHookFunction((void *)SecItemUpdate, (void *)hooked_SecItemUpdate, (void **)&orig_SecItemUpdate);
    MSHookFunction((void *)SecItemDelete, (void *)hooked_SecItemDelete, (void **)&orig_SecItemDelete);

    // 2. تهيئة هوك UIApplication
    %init;

    // 3. تفعيل هوكات الفيسبوك بشرط وجود أحد كلاساتها لتجنب الانهيار
    if (NSClassFromString(@"FBMemFeedItem") || NSClassFromString(@"FBStoryViewerViewController") || NSClassFromString(@"FBLikeButton")) {
        %init(FacebookHooks);
    }
}

#pragma clang diagnostic pop
