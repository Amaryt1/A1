#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define kIconURL @"https://i.ibb.co/nNR6pDdN/4-B524707-0-AB6-47-E7-984-F-1-C5661-B4-F776.jpg"
#define kOptDownloader @"AMARYT_EnableDownloader"
#define kOptBlockAds   @"AMARYT_BlockAds"
#define kOptGhostStory @"AMARYT_GhostStory"
#define kOptGhostMsg   @"AMARYT_GhostMsg"

// ==========================================
// 1. واجهة الإعدادات (Settings VC)
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
// 2. الزر العائم (Floating Button)
// ==========================================
@interface AMARYTFloatingButton : UIView
@property (nonatomic, strong) UIImageView *iconImageView;
@end

@implementation AMARYTFloatingButton

+ (instancetype)sharedButton {
    static AMARYTFloatingButton *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AMARYTFloatingButton alloc] initWithFrame:CGRectMake(20, 160, 56, 56)];
    });
    return instance;
}

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
    
    UIWindow *keyWin = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { keyWin = w; break; }
    }
    if (!keyWin) keyWin = [UIApplication sharedApplication].windows.firstObject;
    
    UIViewController *rootVC = keyWin.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    [rootVC presentViewController:nav animated:YES completion:nil];
}

@end

// ==========================================
// 3. حقن الزر بالواجهة بحماية كاملة
// ==========================================
static void injectFloatingButtonSafely(void) {
    UIWindow *keyWin = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { keyWin = w; break; }
    }
    if (!keyWin) keyWin = [UIApplication sharedApplication].windows.firstObject;
    
    if (keyWin) {
        AMARYTFloatingButton *btn = [AMARYTFloatingButton sharedButton];
        if (!btn.superview || btn.superview != keyWin) {
            [btn removeFromSuperview];
            [keyWin addSubview:btn];
            [keyWin bringSubviewToFront:btn];
        }
    }
}

// ==========================================
// 4. خطافات محمية ومقسمة (Safe Hooks)
// ==========================================
%group AdGroup
%hook FBFeedAdUnit
- (id)init {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kOptBlockAds]) return nil;
    return %orig;
}
%end
%end

%group StoryGroup
%hook FBStorySeenState
- (void)markStoryAsSeen:(id)story {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kOptGhostStory]) return;
    %orig;
}
%end
%end

%group MsgGroup
%hook FBMessagesReadReceipt
- (void)sendReadReceiptForMessage:(id)message {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kOptGhostMsg]) return;
    %orig;
}
%end
%end

// ==========================================
// 5. التهيئة الآمنة (%ctor)
// ==========================================
%ctor {
    NSDictionary *defaultSettings = @{
        kOptDownloader: @YES,
        kOptBlockAds: @YES,
        kOptGhostStory: @YES,
        kOptGhostMsg: @YES
    };
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultSettings];
    
    // فحص الكلاسات قبل ربطها لمنع الانهيار
    if (objc_getClass("FBFeedAdUnit")) { %init(AdGroup); }
    if (objc_getClass("FBStorySeenState")) { %init(StoryGroup); }
    if (objc_getClass("FBMessagesReadReceipt")) { %init(MsgGroup); }
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            injectFloatingButtonSafely();
        });
    }];
}
