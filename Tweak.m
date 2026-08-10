#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// ============================================================================
// 1. التجسير الآمن للكيشين (Dyld Interpose) - حماية تسجيل الدخول واستقرار الجلسة
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
// 2. المتغيرات العامة وإعدادات الميزات
// ============================================================================
static BOOL gGhostStoryEnabled = YES;
static BOOL gGhostDMEnabled    = YES;
static BOOL gViewOnceBypass    = YES;
static NSString *const kBannerImageURL = @"https://i.ibb.co/nNR6pDdN/4-B524707-0-AB6-47-E7-984-F-1-C5661-B4-F776.jpg";

// ============================================================================
// 3. أدوات المساعدة والتحميل
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
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ig_amaryt_download.%@", ext]];
        [data writeToFile:tempPath atomically:YES];

        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            if (isVideo) {
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:tempPath]];
            } else {
                [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:tempPath]];
            }
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✨ IGAMARYT"
                                                                               message:success ? @"تم حفظ المقطع في ألبوم الصور بنجاح! 💾" : @"فشل الحفظ، تحقق من صلاحيات الصور."
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"تم" style:UIAlertActionStyleDefault handler:nil]];
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
            }
        });
    }];
}

static void ShowDownloadOptions(NSURL *videoURL) {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"📥 خيارات التحميل المتقدمة"
                                                                   message:@"اختر جودة ونوع الملف للتحميل:"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"🎥 تحميل الفيديو بأعلى جودة (HQ MP4)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        SaveMediaToAlbum(videoURL, YES);
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"🎵 استخراج وتنزيل الصوت فقط (Audio M4A)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        ExtractAndSaveAudio(videoURL);
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [GetTopViewController() presentViewController:sheet animated:YES completion:nil];
}

// ============================================================================
// 4. الواجهة المنبثقة الاحترافية (Custom Premium Dialog UI)
// ============================================================================
@interface IGAMARYTControlViewController : UIViewController
@end

@implementation IGAMARYTControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:blurView];

    // البطاقة الرئيسية
    UIView *cardView = [[UIView alloc] initWithFrame:CGRectMake(25, (self.view.frame.size.height - 520)/2, self.view.frame.size.width - 50, 520)];
    cardView.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.12 alpha:0.95];
    cardView.layer.cornerRadius = 24;
    cardView.layer.masksToBounds = YES;
    cardView.layer.borderWidth = 1.5;
    cardView.layer.borderColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.45 alpha:0.6].CGColor;
    [self.view addSubview:cardView];

    // صورة الغلاف المجلوبة من الرابط
    UIImageView *bannerImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, cardView.frame.size.width, 160)];
    bannerImageView.contentMode = UIViewContentModeScaleAspectFill;
    bannerImageView.clipsToBounds = YES;
    bannerImageView.backgroundColor = [UIColor darkGrayColor];
    [cardView addSubview:bannerImageView];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:kBannerImageURL]];
        if (data) {
            UIImage *img = [UIImage imageWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{
                bannerImageView.image = img;
            });
        }
    });

    // عنوان الواجهة
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 170, cardView.frame.size.width - 30, 30)];
    titleLabel.text = @"🔥 IGAMARYT VIP PRO";
    titleLabel.textColor = [UIColor colorWithRed:0.98 green:0.35 blue:0.55 alpha:1.0];
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [cardView addSubview:titleLabel];

    // صفوف الميزات مع المفاتيح الملونة
    [self addFeatureToggleInCard:cardView yPos:215 title:@"👁️ التخفي في الستوري (Ghost Story)" defaultVal:gGhostStoryEnabled action:@selector(toggleGhostStory:)];
    [self addFeatureToggleInCard:cardView yPos:265 title:@"💬 التخفي في المحادثات (Hide Seen)" defaultVal:gGhostDMEnabled action:@selector(toggleGhostDM:)];
    [self addFeatureToggleInCard:cardView yPos:315 title:@"♾️ تكرار مشاهدة الصور المؤقتة" defaultVal:gViewOnceBypass action:@selector(toggleViewOnce:)];

    // زر التنزيل السريع المباشر
    UIButton *downloadNowBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    downloadNowBtn.frame = CGRectMake(20, 375, cardView.frame.size.width - 40, 48);
    downloadNowBtn.backgroundColor = [UIColor colorWithRed:0.88 green:0.20 blue:0.42 alpha:1.0];
    downloadNowBtn.layer.cornerRadius = 14;
    [downloadNowBtn setTitle:@"⬇️ تحميل الريل / المقطع الحالي" forState:UIControlStateNormal];
    downloadNowBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [downloadNowBtn addTarget:self action:@selector(downloadCurrentMedia) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:downloadNowBtn];

    // زر إغلاق الواجهة
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(20, 435, cardView.frame.size.width - 40, 45);
    closeBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    closeBtn.layer.cornerRadius = 14;
    [closeBtn setTitle:@"إغلاق الواجهة" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [closeBtn addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:closeBtn];
}

- (void)addFeatureToggleInCard:(UIView *)card yPos:(CGFloat)y title:(NSString *)title defaultVal:(BOOL)val action:(SEL)action {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(20, y, card.frame.size.width - 90, 35)];
    lbl.text = title;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [card addSubview:lbl];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(card.frame.size.width - 70, y, 50, 30)];
    sw.on = val;
    sw.onTintColor = [UIColor colorWithRed:0.90 green:0.25 blue:0.50 alpha:1.0];
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [card addSubview:sw];
}

- (void)toggleGhostStory:(UISwitch *)sw { gGhostStoryEnabled = sw.isOn; }
- (void)toggleGhostDM:(UISwitch *)sw    { gGhostDMEnabled = sw.isOn; }
- (void)toggleViewOnce:(UISwitch *)sw   { gViewOnceBypass = sw.isOn; }

- (void)downloadCurrentMedia {
    [self dismissViewControllerAnimated:YES completion:^{
        NSURL *vURL = ExtractVideoURLFromView([UIApplication sharedApplication].keyWindow);
        if (vURL) {
            ShowDownloadOptions(vURL);
        } else {
            UIAlertController *err = [UIAlertController alertControllerWithTitle:@"IGAMARYT" message:@"افتح الريل أو المنشور أولاً ليتعرف عليه النظام." preferredStyle:UIAlertControllerStyleAlert];
            [err addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
            [GetTopViewController() presentViewController:err animated:YES completion:nil];
        }
    }];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// ============================================================================
// 5. زر التحميل التلقائي فوق زر اللايك / الريلز (Swizzling)
// ============================================================================
static void amaryt_downloadAction(id self, SEL _cmd, UIButton *sender) {
    NSURL *vURL = ExtractVideoURLFromView([UIApplication sharedApplication].keyWindow);
    if (vURL) {
        ShowDownloadOptions(vURL);
    } else {
        UIAlertController *err = [UIAlertController alertControllerWithTitle:@"IGAMARYT" message:@"جاري معالجة الفيديو، جرب الضغط مجدداً خلال ثوانٍ." preferredStyle:UIAlertControllerStyleAlert];
        [err addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
        [GetTopViewController() presentViewController:err animated:YES completion:nil];
    }
}

static void (*orig_IGLikeButton_layoutSubviews)(id self, SEL _cmd);
static void my_IGLikeButton_layoutSubviews(UIView *self, SEL _cmd) {
    orig_IGLikeButton_layoutSubviews(self, _cmd);

    UIView *parent = self.superview;
    if (!parent) return;

    if ([parent viewWithTag:998811]) return; // منع تكرار الإنشاء

    UIButton *dlBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    dlBtn.tag = 998811;
    CGFloat width = self.frame.size.width > 0 ? self.frame.size.width : 42;
    dlBtn.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y - 50, width, 42);
    dlBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.15 blue:0.40 alpha:0.85];
    dlBtn.layer.cornerRadius = 21;
    dlBtn.clipsToBounds = YES;
    [dlBtn setTitle:@"⬇️" forState:UIControlStateNormal];
    dlBtn.titleLabel.font = [UIFont systemFontOfSize:18];

    [dlBtn addTarget:self action:@selector(amaryt_downloadTriggered:) forControlEvents:UIControlEventTouchUpInside];
    [parent addSubview:dlBtn];
}

// ============================================================================
// 6. Swizzling للميزات الأخرى وتفعيل الإقلاع
// ============================================================================
static BOOL (*orig_isExpired)(id self, SEL _cmd);
static BOOL my_isExpired(id self, SEL _cmd) {
    return gViewOnceBypass ? NO : orig_isExpired(self, _cmd);
}

static BOOL (*orig_canReplay)(id self, SEL _cmd);
static BOOL my_canReplay(id self, SEL _cmd) {
    return gViewOnceBypass ? YES : orig_canReplay(self, _cmd);
}

static void (*orig_markAsRead)(id self, SEL _cmd, id arg1);
static void my_markAsRead(id self, SEL _cmd, id arg1) {
    if (gGhostDMEnabled || gGhostStoryEnabled) return;
    orig_markAsRead(self, _cmd, arg1);
}

__attribute__((constructor))
static void initIGAMARYTPlugin(void) {
    // 1. حقن زر التنزيل فوق زر اللايك في انستغرام
    Class likeClass = NSClassFromString(@"IGBouncingButton") ?: NSClassFromString(@"IGFeedItemLikeButton");
    if (likeClass) {
        Method m = class_getInstanceMethod(likeClass, @selector(layoutSubviews));
        if (m) {
            class_addMethod(likeClass, @selector(amaryt_downloadTriggered:), (IMP)amaryt_downloadAction, "v@:@");
            orig_IGLikeButton_layoutSubviews = (void (*)(id, SEL))method_getImplementation(m);
            method_setImplementation(m, (IMP)my_IGLikeButton_layoutSubviews);
        }
    }

    // 2. Swizzling لفتح الصور والفيديوهات المؤقتة
    Class visualMsgClass = NSClassFromString(@"IGDirectVisualMessage") ?: NSClassFromString(@"IGDirectVisualMedia");
    if (visualMsgClass) {
        Method m1 = class_getInstanceMethod(visualMsgClass, @selector(isExpired));
        if (m1) {
            orig_isExpired = (BOOL (*)(id, SEL))method_getImplementation(m1);
            method_setImplementation(m1, (IMP)my_isExpired);
        }
        Method m2 = class_getInstanceMethod(visualMsgClass, @selector(canReplay));
        if (m2) {
            orig_canReplay = (BOOL (*)(id, SEL))method_getImplementation(m2);
            method_setImplementation(m2, (IMP)my_canReplay);
        }
    }

    // 3. Swizzling للتخفي في السين (Seen Block)
    Class threadClass = NSClassFromString(@"IGDirectThreadDataController") ?: NSClassFromString(@"IGStoryDataController");
    if (threadClass) {
        Method mMark = class_getInstanceMethod(threadClass, @selector(markAsRead:));
        if (mMark) {
            orig_markAsRead = (void (*)(id, SEL, id))method_getImplementation(mMark);
            method_setImplementation(mMark, (IMP)my_markAsRead);
        }
    }

    // 4. عرض النافذة المنبثقة الفخمة عند تشغيل التطبيق
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                IGAMARYTControlViewController *vc = [[IGAMARYTControlViewController alloc] init];
                vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
                vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
                [GetTopViewController() presentViewController:vc animated:YES completion:nil];
            });
        });
    }];
}

#pragma clang diagnostic pop
