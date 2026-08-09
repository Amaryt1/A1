#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

// --- التعريفات والثوابت ---
#define kIconURL @"https://i.ibb.co/nNR6pDdN/4-B524707-0-AB6-47-E7-984-F-1-C5661-B4-F776.jpg"
#define kOptDownloader @"AMARYT_EnableDownloader"
#define kOptBlockAds   @"AMARYT_BlockAds"
#define kOptGhostStory @"AMARYT_GhostStory"
#define kOptGhostMsg   @"AMARYT_GhostMsg"
#define kOptCopyText   @"AMARYT_CopyText"

// ==========================================
// 1. واجهة الإعدادات (Settings View Controller)
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
    return 5;
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
            cell.textLabel.text = @"⬇️ تحميل الريلز والمقاطع";
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
        case 4:
            cell.textLabel.text = @"📋 تفعيل نسخ النصوص عند الضغط المطوّل";
            switchControl.on = [defaults boolForKey:kOptCopyText];
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
        case 4: [defaults setBool:sender.isOn forKey:kOptCopyText]; break;
    }
    [defaults synchronize];
}

@end

// ==========================================
// 2. الزر العائم القابل للتحريك (Floating Movable Button)
// ==========================================
@interface AMARYTFloatingButton : UIView
@property (nonatomic, strong) UIImageView *iconImageView;
@end

@implementation AMARYTFloatingButton

+ (instancetype)sharedButton {
    static AMARYTFloatingButton *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AMARYTFloatingButton alloc] initWithFrame:CGRectMake(20, 160, 58, 58)];
    });
    return instance;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = 29;
        self.layer.masksToBounds = NO;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 4);
        self.layer.shadowOpacity = 0.4;
        self.layer.shadowRadius = 6;
        
        self.iconImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.iconImageView.layer.cornerRadius = 29;
        self.iconImageView.clipsToBounds = YES;
        self.iconImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.iconImageView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
        [self addSubview:self.iconImageView];
        
        // تحميل الصورة من الرابط المباشر
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:kIconURL]];
            if (imageData) {
                UIImage *img = [UIImage imageWithData:imageData];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.iconImageView.image = img;
                });
            }
        });
        
        // إيماءة التحريك والتعديل على الموقع (Pan Gesture)
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
        [self addGestureRecognizer:pan];
        
        // إيماءة الضغط لتطوير القائمة (Tap Gesture)
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self.superview];
    
    // الانجذاب إلى حواف الشاشة عند الاستقرار
    if (pan.state == UIGestureRecognizerStateEnded) {
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat targetX = (self.center.x < screenWidth / 2) ? 38 : (screenWidth - 38);
        [UIView animateWithDuration:0.25 animations:^{
            self.center = CGPointMake(targetX, self.center.y);
        }];
    }
}

- (void)handleTapGesture {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
    
    AMARYTSettingsVC *settingsVC = [[AMARYTSettingsVC alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    
    UIWindow *window = self.window;
    UIViewController *rootVC = window.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    [rootVC presentViewController:nav animated:YES completion:nil];
}

@end

// ==========================================
// 3. حقن الزر العائم في النافذة الرئيسية للتطبيق
// ==========================================
%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    AMARYTFloatingButton *btn = [AMARYTFloatingButton sharedButton];
    if (!btn.superview) {
        [self addSubview:btn];
    }
}
%end

// ==========================================
// 4. تطبيق الميزات بحسب التفضيلات (Hooks)
// ==========================================

// إزالة الإعلانات
%hook FBFeedAdUnit
- (id)init {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kOptBlockAds]) return nil;
    return %orig;
}
%end

// مشاهدة الستوري مخفي
%hook FBStorySeenState
- (void)markStoryAsSeen:(id)story {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kOptGhostStory]) return;
    %orig;
}
%end

// مشاهدة الرسائل مخفي
%hook FBMessagesReadReceipt
- (void)sendReadReceiptForMessage:(id)message {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kOptGhostMsg]) return;
    %orig;
}
%end

// نسخ النصوص عند الضغط المطول
%hook UILabel
- (void)layoutSubviews {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kOptCopyText]) return;
    
    self.userInteractionEnabled = YES;
    BOOL hasGesture = NO;
    for (UIGestureRecognizer *g in self.gestureRecognizers) {
        if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) {
            hasGesture = YES;
            break;
        }
    }
    if (!hasGesture) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(amarytCopyTextGesture:)];
        [self addGestureRecognizer:longPress];
    }
}

%new
- (void)amarytCopyTextGesture:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan && self.text.length > 0) {
        [UIPasteboard generalPasteboard].string = self.text;
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [fb impactOccurred];
    }
}
%end

// زر تحميل الفيديو والريلز
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
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AMARYT Tools" message:@"تم حفظ الفيديو في ألبوم الصور بنجاح ✅" preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            });
        }
    });
}
%end
