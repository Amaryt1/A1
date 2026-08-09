#import <UIKit/UIKit.h>

#define kIconURL @"https://i.ibb.co/nNR6pDdN/4-B524707-0-AB6-47-E7-984-F-1-C5661-B4-F776.jpg"
#define kOptDownloader @"AMARYT_EnableDownloader"
#define kOptBlockAds   @"AMARYT_BlockAds"
#define kOptGhostStory @"AMARYT_GhostStory"
#define kOptGhostMsg   @"AMARYT_GhostMsg"

// ==========================================
// 1. نافذة عائمة مستقلة تضمن عدم اختفاء الزر (Pass-Through Overlay Window)
// ==========================================
@interface AMARYTWindow : UIWindow
@end

@implementation AMARYTWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self || hitView == self.rootViewController.view) {
        return nil; // التمرير للفيسبوك تحت النافذة إذا لم يُضغط على الزر مباشرة
    }
    return hitView;
}
@end

// ==========================================
// 2. واجهة الإعدادات (Settings VC)
// ==========================================
@interface AMARYTSettingsVC : UITableViewController
@end

@implementation AMARYTSettingsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"أدوات AMARYT";
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SettingCell"];
    
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"إغلاق" style:UIBarButtonItemStyleDone target:self action:@selector(closeSettings)];
    self.navigationItem.rightBarButtonItem = closeButton;
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    UISwitch *switchControl = [[UISwitch alloc] init];
    switchControl.onTintColor = [UIColor systemBlueColor];
    switchControl.tag = indexPath.row;
    [switchControl addTarget:self action:@selector(switchStateChanged:) forControlEvents:UIControlEventValueChanged];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"⬇️ زر تحميل المقاطع والريلز";
            switchControl.on = [defaults boolForKey:kOptDownloader];
            break;
        case 1:
            cell.textLabel.text = @"🚫 إزالة الإعلانات والمنشورات المموّلة";
            switchControl.on = [defaults boolForKey:kOptBlockAds];
            break;
        case 2:
            cell.textLabel.text = @"👻 مشاهدة الستوري بدون علم صاحبها";
            switchControl.on = [defaults boolForKey:kOptGhostStory];
            break;
        case 3:
            cell.textLabel.text = @"👁️ مشاهدة الرسائل بدون إشعار القراءة";
            switchControl.on = [defaults boolForKey:kOptGhostMsg];
            break;
    }
    
    cell.accessoryView = switchControl;
    return cell;
}

- (void)switchStateChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    switch (sender.tag) {
        case 0: [defaults setBool:sender.isOn forKey:kOptDownloader]; break;
        case 1: [defaults setBool:sender.isOn forKey:kOptBlockAds]; break;
        case 2: [defaults setBool:sender.isOn forKey:kOptGhostStory]; break;
        case 3: [defaults setBool:sender.isOn forKey:kOptGhostMsg]; break;
    }
    [defaults synchronize];
}

@end

// ==========================================
// 3. الزر العائم (Floating Button)
// ==========================================
@interface AMARYTFloatingButton : UIView
@property (nonatomic, strong) UIImageView *iconImageView;
@end

@implementation AMARYTFloatingButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = 28;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 4);
        self.layer.shadowOpacity = 0.5;
        self.layer.shadowRadius = 6;
        
        self.iconImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.iconImageView.layer.cornerRadius = 28;
        self.iconImageView.clipsToBounds = YES;
        self.iconImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.iconImageView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        [self addSubview:self.iconImageView];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:kIconURL]];
            if (imageData) {
                UIImage *img = [UIImage imageWithData:imageData];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.iconImageView.image = img;
                });
            }
        });
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
        [self addGestureRecognizer:pan];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self.superview];
    
    if (pan.state == UIGestureRecognizerStateEnded) {
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat targetX = (self.center.x < screenWidth / 2) ? 38 : (screenWidth - 38);
        [UIView animateWithDuration:0.25 animations:^{
            self.center = CGPointMake(targetX, self.center.y);
        }];
    }
}

- (void)handleTapGesture {
    AMARYTSettingsVC *settingsVC = [[AMARYTSettingsVC alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    
    UIViewController *rootVC = self.window.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    [rootVC presentViewController:nav animated:YES completion:nil];
}

@end

// ==========================================
// 4. مدير النافذة المرتفعة (Overlay Manager)
// ==========================================
static AMARYTWindow *gOverlayWindow = nil;

static void setupOverlayWindow(void) {
    if (gOverlayWindow) return;
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    gOverlayWindow = [[AMARYTWindow alloc] initWithFrame:screenBounds];
    gOverlayWindow.windowLevel = UIWindowLevelAlert + 10;
    gOverlayWindow.backgroundColor = [UIColor clearColor];
    
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    gOverlayWindow.rootViewController = vc;
    
    AMARYTFloatingButton *btn = [[AMARYTFloatingButton alloc] initWithFrame:CGRectMake(20, 160, 56, 56)];
    [vc.view addSubview:btn];
    
    gOverlayWindow.hidden = NO;
}

// ==========================================
// 5. تهيئة الميزات وتفعيلها افتراضياً (%ctor)
// ==========================================
%ctor {
    // تفعيل جميع الميزات تلقائياً فور أول تثبيت
    NSDictionary *defaultSettings = @{
        kOptDownloader: @YES,
        kOptBlockAds: @YES,
        kOptGhostStory: @YES,
        kOptGhostMsg: @YES
    };
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultSettings];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            setupOverlayWindow();
        });
    }];
}

// ==========================================
// 6. خطافات التفعيل (Hooks)
// ==========================================

%hook FBFeedAdUnit
- (id)init {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kOptBlockAds]) return nil;
    return %orig;
}
%end

%hook FBStorySeenState
- (void)markStoryAsSeen:(id)story {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kOptGhostStory]) return;
    %orig;
}
%end

%hook FBMessagesReadReceipt
- (void)sendReadReceiptForMessage:(id)message {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kOptGhostMsg]) return;
    %orig;
}
%end

@interface FBVideoPlayerViewController : UIViewController
@property (nonatomic, strong) NSURL *videoURL;
@end

%hook FBVideoPlayerViewController
- (void)viewDidLoad {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kOptDownloader]) return;
    
    UIButton *dlBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    dlBtn.frame = CGRectMake(self.view.frame.size.width - 55, 120, 44, 44);
    [dlBtn setTitle:@"⬇️" forState:UIControlStateNormal];
    dlBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    dlBtn.layer.cornerRadius = 22;
    [dlBtn addTarget:self action:@selector(amarytDownloadMediaAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:dlBtn];
}

%new
- (void)amarytDownloadMediaAction {
    NSURL *url = self.videoURL;
    if (!url) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (data) {
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"fb_download.mp4"];
            [data writeToFile:path atomically:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                UISaveVideoAtPathToSavedPhotosAlbum(path, nil, nil, nil);
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AMARYT Tools" message:@"تم حفظ الفيديو في الاستوديو بنجاح ✅" preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            });
        }
    });
}
%end
