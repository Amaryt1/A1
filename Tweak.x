#import <UIKit/UIKit.h>

%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWin = nil;
            for (UIWindow *w in [UIApplication sharedApplication].windows) {
                if (w.isKeyWindow) { keyWin = w; break; }
            }
            if (!keyWin) keyWin = [UIApplication sharedApplication].windows.firstObject;

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AMARYT Tools"
                                                                           message:@"التطبيق يعمل والدايلوب متوافق بنجاح! ✅"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
            
            UIViewController *rootVC = keyWin.rootViewController;
            while (rootVC.presentedViewController) {
                rootVC = rootVC.presentedViewController;
            }
            [rootVC presentViewController:alert animated:YES completion:nil];
        });
    }];
}
