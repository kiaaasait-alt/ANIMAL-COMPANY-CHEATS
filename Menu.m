#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <sys/mman.h>
#import <libkern/OSCacheControl.h>

// ─────────────────────────────────────────
// Yeeps VR – VRX Client
// Unity iOS — Il2Cpp inside UnityFramework
// ─────────────────────────────────────────

#pragma mark - Type Definitions

typedef void*    Il2CppString;
typedef void*    Il2CppObject;
typedef void*    Il2CppDomain;
typedef void*    Il2CppAssembly;
typedef void*    Il2CppImage;
typedef void*    Il2CppClass;
typedef void*    Il2CppMethod;
typedef void*    Il2CppField;

typedef struct { float x, y, z; }    Vector3;
typedef struct { float x, y, z, w; } Quaternion;

#pragma mark - Il2Cpp API Function Pointers

static Il2CppDomain*   (*_il2cpp_domain_get)(void) = NULL;
static Il2CppAssembly* (*_il2cpp_domain_assembly_open)(Il2CppDomain*, const char*) = NULL;
static Il2CppImage*    (*_il2cpp_assembly_get_image)(Il2CppAssembly*) = NULL;
static Il2CppClass*    (*_il2cpp_class_from_name)(Il2CppImage*, const char*, const char*) = NULL;
static Il2CppMethod*   (*_il2cpp_class_get_method_from_name)(Il2CppClass*, const char*, int) = NULL;
static Il2CppObject*   (*_il2cpp_runtime_invoke)(Il2CppMethod*, void*, void**, Il2CppObject**) = NULL;
static Il2CppField*    (*_il2cpp_class_get_field_from_name)(Il2CppClass*, const char*) = NULL;
static void            (*_il2cpp_field_static_get_value)(Il2CppField*, void*) = NULL;
static void            (*_il2cpp_field_set_value)(Il2CppObject*, Il2CppField*, void*) = NULL;

#pragma mark - State

static BOOL _resolved = NO;
static dispatch_once_t _resolveOnceToken;

static UIWindow  *menuWindow;
static UIView    *menuPanel;
static BOOL       menuVisible;

static UIView    *playerTabView;
static UIView    *gameTabView;
static UIView    *visualTabView;

static UIButton  *playerTabBtn;
static UIButton  *gameTabBtn;
static UIButton  *visualTabBtn;

static NSInteger  _currentTabIndex = 0;

// Mod states
static BOOL speedBoostEnabled = NO;
static BOOL superJumpEnabled = NO;
static BOOL noClipEnabled = NO;
static BOOL infiniteLivesEnabled = NO;
static BOOL freezeTimerEnabled = NO;
static BOOL rgbModeEnabled = NO;
static BOOL fullBrightEnabled = NO;

#pragma mark - Forward Declarations

static void resolveSymbols(void);
static Il2CppImage *getYeepsImage(void);
static void setSpeedBoost(BOOL enabled);
static void setSuperJump(BOOL enabled);
static void setNoClip(BOOL enabled);
static void setInfiniteLives(BOOL enabled);
static void setFreezeTimer(BOOL enabled);
static void setRGBMode(BOOL enabled);
static void setFullBright(BOOL enabled);
static void toggleMenu(void);
static void switchToTab(NSInteger tab);
static UIScrollView *buildPlayerTab(CGFloat w, CGFloat h);
static UIScrollView *buildGameTab(CGFloat w, CGFloat h);
static UIScrollView *buildVisualTab(CGFloat w, CGFloat h);
static void createMenuPanel(void);
static void createToggleButton(void);
static void setupMenu(void);

#pragma mark - Unity Framework Resolution

static void *getUnityFrameworkHandle(void) {
    void *h = dlopen("@rpath/UnityFramework.framework/UnityFramework", RTLD_NOLOAD | RTLD_LAZY);
    if (h) return h;
    
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, "UnityFramework")) {
            h = dlopen(name, RTLD_NOLOAD | RTLD_LAZY);
            if (h) return h;
        }
    }
    return NULL;
}

static void resolveSymbols(void) {
    dispatch_once(&_resolveOnceToken, ^{
        void *fw = getUnityFrameworkHandle();
        if (!fw) return;

        #define RESOLVE(fn) _##fn = dlsym(fw, #fn)
        RESOLVE(il2cpp_domain_get);
        RESOLVE(il2cpp_domain_assembly_open);
        RESOLVE(il2cpp_assembly_get_image);
        RESOLVE(il2cpp_class_from_name);
        RESOLVE(il2cpp_class_get_method_from_name);
        RESOLVE(il2cpp_runtime_invoke);
        RESOLVE(il2cpp_class_get_field_from_name);
        RESOLVE(il2cpp_field_static_get_value);
        RESOLVE(il2cpp_field_set_value);
        #undef RESOLVE

        _resolved = (_il2cpp_domain_get && _il2cpp_class_from_name);
    });
}

static Il2CppImage *getYeepsImage(void) {
    if (!_il2cpp_domain_get) return NULL;
    Il2CppDomain *domain = _il2cpp_domain_get();
    if (!domain) return NULL;
    
    Il2CppAssembly *assembly = _il2cpp_domain_assembly_open(domain, "Assembly-CSharp");
    if (!assembly) return NULL;
    
    return _il2cpp_assembly_get_image(assembly);
}

#pragma mark - Mod Functions

static void setSpeedBoost(BOOL enabled) {
    speedBoostEnabled = enabled;
    // Hook player movement speed multiplier here
    NSLog(@"[VRX] Speed Boost: %@", enabled ? @"ON" : @"OFF");
}

static void setSuperJump(BOOL enabled) {
    superJumpEnabled = enabled;
    // Hook player jump force here
    NSLog(@"[VRX] Super Jump: %@", enabled ? @"ON" : @"OFF");
}

static void setNoClip(BOOL enabled) {
    noClipEnabled = enabled;
    // Disable collision detection here
    NSLog(@"[VRX] No Clip: %@", enabled ? @"ON" : @"OFF");
}

static void setInfiniteLives(BOOL enabled) {
    infiniteLivesEnabled = enabled;
    // Hook life counter here
    NSLog(@"[VRX] Infinite Lives: %@", enabled ? @"ON" : @"OFF");
}

static void setFreezeTimer(BOOL enabled) {
    freezeTimerEnabled = enabled;
    // Hook timer countdown here
    NSLog(@"[VRX] Freeze Timer: %@", enabled ? @"ON" : @"OFF");
}

static void setRGBMode(BOOL enabled) {
    rgbModeEnabled = enabled;
    // Add rainbow color effects here
    NSLog(@"[VRX] RGB Mode: %@", enabled ? @"ON" : @"OFF");
}

static void setFullBright(BOOL enabled) {
    fullBrightEnabled = enabled;
    // Remove darkness/shadows here
    NSLog(@"[VRX] Full Bright: %@", enabled ? @"ON" : @"OFF");
}

#pragma mark - UI Helpers

static void toggleMenu(void) {
    menuVisible = !menuVisible;
    [UIView animateWithDuration:0.22
                     animations:^{ 
                         if (menuPanel) menuPanel.alpha = menuVisible ? 1.0 : 0.0; 
                     }
                     completion:^(BOOL finished){ 
                         if (menuPanel) menuPanel.hidden = !menuVisible; 
                     }];
}

static UIColor *tabActiveColor(void) { 
    return [UIColor colorWithRed:0.55 green:0.3 blue:0.85 alpha:1]; 
}

static UIColor *tabInactiveColor(void) { 
    return [UIColor colorWithRed:0.25 green:0.12 blue:0.35 alpha:1]; 
}

static void switchToTab(NSInteger tab) {
    _currentTabIndex = tab;
    if (playerTabView) playerTabView.hidden = (tab != 0);
    if (gameTabView) gameTabView.hidden = (tab != 1);
    if (visualTabView) visualTabView.hidden = (tab != 2);
    
    if (playerTabBtn) playerTabBtn.backgroundColor = (tab == 0) ? tabActiveColor() : tabInactiveColor();
    if (gameTabBtn) gameTabBtn.backgroundColor = (tab == 1) ? tabActiveColor() : tabInactiveColor();
    if (visualTabBtn) visualTabBtn.backgroundColor = (tab == 2) ? tabActiveColor() : tabInactiveColor();
}

#pragma mark - UI Classes

@interface VRXPassthroughWindow : UIWindow @end
@implementation VRXPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self.rootViewController.view) return nil;
    return hit;
}
@end

@interface VRXDragButton : UIButton
@property (nonatomic, assign) BOOL didDrag;
@end
@implementation VRXDragButton
- (void)tapped { if (!self.didDrag) toggleMenu(); }
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint d = [pan translationInView:self.superview];
    CGRect f = self.frame, s = UIScreen.mainScreen.bounds;
    f.origin.x = MAX(0, MIN(f.origin.x+d.x, s.size.width-f.size.width));
    f.origin.y = MAX(20, MIN(f.origin.y+d.y, s.size.height-f.size.height));
    self.frame = f; [pan setTranslation:CGPointZero inView:self.superview];
    self.didDrag = YES;
    if (pan.state == UIGestureRecognizerStateEnded) self.didDrag = NO;
}
@end

@interface VRXPanView : UIView @end
@implementation VRXPanView
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint d = [pan translationInView:self.superview];
    CGRect f = self.frame, s = UIScreen.mainScreen.bounds;
    f.origin.x = MAX(0, MIN(f.origin.x+d.x, s.size.width-f.size.width));
    f.origin.y = MAX(20, MIN(f.origin.y+d.y, s.size.height-f.size.height));
    self.frame = f; [pan setTranslation:CGPointZero inView:self.superview];
}
@end

@interface VRXBtn : UIButton
@property (nonatomic, copy) void(^action)(UIButton *);
@end
@implementation VRXBtn
- (void)tapped { if (self.action) self.action(self); }
@end

#pragma mark - Tab Builders

static VRXBtn *makeToggle(NSString *icon, NSString *name, NSString *desc, 
                          CGRect frame, BOOL *statePtr, void(^setter)(BOOL)) {
    VRXBtn *b = [VRXBtn buttonWithType:UIButtonTypeSystem];
    b.frame = frame;
    b.layer.cornerRadius = 8;
    b.backgroundColor = [UIColor colorWithRed:0.06 green:0.04 blue:0.12 alpha:1];
    b.layer.borderWidth = 1;
    b.layer.borderColor = [UIColor colorWithRed:0.3 green:0.15 blue:0.5 alpha:0.5].CGColor;
    
    UILabel *iconLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 12, 26, 26)];
    iconLbl.text = icon;
    iconLbl.font = [UIFont systemFontOfSize:20];
    iconLbl.userInteractionEnabled = NO;
    [b addSubview:iconLbl];
    
    UILabel *nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(45, 8, frame.size.width-95, 18)];
    nameLbl.text = name;
    nameLbl.textColor = [UIColor colorWithRed:0.9 green:0.85 blue:0.95 alpha:1];
    nameLbl.font = [UIFont boldSystemFontOfSize:13];
    nameLbl.userInteractionEnabled = NO;
    [b addSubview:nameLbl];
    
    UILabel *descLbl = [[UILabel alloc] initWithFrame:CGRectMake(45, 26, frame.size.width-95, 16)];
    descLbl.text = desc;
    descLbl.textColor = [UIColor colorWithRed:0.5 green:0.4 blue:0.6 alpha:1];
    descLbl.font = [UIFont systemFontOfSize:9];
    descLbl.userInteractionEnabled = NO;
    [b addSubview:descLbl];
    
    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(frame.size.width-65, 9, 51, 31)];
    toggle.onTintColor = [UIColor colorWithRed:0.55 green:0.3 blue:0.85 alpha:1];
    toggle.tag = 999;
    toggle.userInteractionEnabled = NO;
    [b addSubview:toggle];
    
    b.action = ^(UIButton *btn) {
        *statePtr = !(*statePtr);
        setter(*statePtr);
        UISwitch *sw = (UISwitch *)[btn viewWithTag:999];
        [sw setOn:*statePtr animated:YES];
    };
    [b addTarget:b action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static UIScrollView *buildPlayerTab(CGFloat w, CGFloat h) {
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    sv.backgroundColor = UIColor.clearColor;
    sv.alwaysBounceVertical = YES;
    
    CGFloat pad = 15, gap = 10, rowH = 50;
    CGFloat totalH = gap + 25 + gap + (rowH+gap)*3 + 20;
    
    UIView *content = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, totalH)];
    [sv addSubview:content];
    sv.contentSize = CGSizeMake(w, totalH);
    
    CGFloat cy = gap;
    
    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 25)];
    hdr.text = @"🏃 PLAYER MODS";
    hdr.backgroundColor = [UIColor colorWithRed:0.35 green:0.15 blue:0.5 alpha:1];
    hdr.layer.cornerRadius = 6;
    hdr.clipsToBounds = YES;
    hdr.textColor = [UIColor whiteColor];
    hdr.font = [UIFont boldSystemFontOfSize:13];
    hdr.textAlignment = NSTextAlignmentCenter;
    [content addSubview:hdr]; cy += 25+gap;
    
    [content addSubview:makeToggle(@"⚡", @"Speed Boost", @"Increase movement speed",
        CGRectMake(pad, cy, w-pad*2, rowH), &speedBoostEnabled, ^(BOOL on){ setSpeedBoost(on); })];
    cy += rowH+gap;
    
    [content addSubview:makeToggle(@"🦘", @"Super Jump", @"Jump higher than normal",
        CGRectMake(pad, cy, w-pad*2, rowH), &superJumpEnabled, ^(BOOL on){ setSuperJump(on); })];
    cy += rowH+gap;
    
    [content addSubview:makeToggle(@"👻", @"No Clip", @"Walk through walls",
        CGRectMake(pad, cy, w-pad*2, rowH), &noClipEnabled, ^(BOOL on){ setNoClip(on); })];
    
    return sv;
}

static UIScrollView *buildGameTab(CGFloat w, CGFloat h) {
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    sv.backgroundColor = UIColor.clearColor;
    sv.alwaysBounceVertical = YES;
    
    CGFloat pad = 15, gap = 10, rowH = 50;
    CGFloat totalH = gap + 25 + gap + (rowH+gap)*2 + 20;
    
    UIView *content = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, totalH)];
    [sv addSubview:content];
    sv.contentSize = CGSizeMake(w, totalH);
    
    CGFloat cy = gap;
    
    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 25)];
    hdr.text = @"🎮 GAME MODS";
    hdr.backgroundColor = [UIColor colorWithRed:0.35 green:0.15 blue:0.5 alpha:1];
    hdr.layer.cornerRadius = 6;
    hdr.clipsToBounds = YES;
    hdr.textColor = [UIColor whiteColor];
    hdr.font = [UIFont boldSystemFontOfSize:13];
    hdr.textAlignment = NSTextAlignmentCenter;
    [content addSubview:hdr]; cy += 25+gap;
    
    [content addSubview:makeToggle(@"🌟", @"Infinite Lives", @"Never lose a life",
        CGRectMake(pad, cy, w-pad*2, rowH), &infiniteLivesEnabled, ^(BOOL on){ setInfiniteLives(on); })];
    cy += rowH+gap;
    
    [content addSubview:makeToggle(@"⏱️", @"Freeze Timer", @"Stop the countdown timer",
        CGRectMake(pad, cy, w-pad*2, rowH), &freezeTimerEnabled, ^(BOOL on){ setFreezeTimer(on); })];
    
    return sv;
}

static UIScrollView *buildVisualTab(CGFloat w, CGFloat h) {
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    sv.backgroundColor = UIColor.clearColor;
    sv.alwaysBounceVertical = YES;
    
    CGFloat pad = 15, gap = 10, rowH = 50;
    CGFloat totalH = gap + 25 + gap + (rowH+gap)*2 + 20;
    
    UIView *content = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, totalH)];
    [sv addSubview:content];
    sv.contentSize = CGSizeMake(w, totalH);
    
    CGFloat cy = gap;
    
    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 25)];
    hdr.text = @"👁️ VISUAL MODS";
    hdr.backgroundColor = [UIColor colorWithRed:0.35 green:0.15 blue:0.5 alpha:1];
    hdr.layer.cornerRadius = 6;
    hdr.clipsToBounds = YES;
    hdr.textColor = [UIColor whiteColor];
    hdr.font = [UIFont boldSystemFontOfSize:13];
    hdr.textAlignment = NSTextAlignmentCenter;
    [content addSubview:hdr]; cy += 25+gap;
    
    [content addSubview:makeToggle(@"🌈", @"RGB Mode", @"Rainbow color effects",
        CGRectMake(pad, cy, w-pad*2, rowH), &rgbModeEnabled, ^(BOOL on){ setRGBMode(on); })];
    cy += rowH+gap;
    
    [content addSubview:makeToggle(@"🔦", @"Full Bright", @"Remove all darkness",
        CGRectMake(pad, cy, w-pad*2, rowH), &fullBrightEnabled, ^(BOOL on){ setFullBright(on); })];
    
    return sv;
}

#pragma mark - Menu Construction

static void createMenuPanel(void) {
    CGRect scr = UIScreen.mainScreen.bounds;
    CGFloat w = scr.size.width * 0.80, pH = scr.size.height * 0.75;
    CGFloat x = (scr.size.width - w) / 2.0, y = (scr.size.height - pH) / 2.0;
    
    VRXPanView *panel = [[VRXPanView alloc] initWithFrame:CGRectMake(x, y, w, pH)];
    panel.backgroundColor = [UIColor colorWithRed:0.08 green:0.05 blue:0.15 alpha:0.97];
    panel.layer.cornerRadius = 12;
    panel.layer.borderWidth = 1.5;
    panel.layer.borderColor = [UIColor colorWithRed:0.35 green:0.15 blue:0.55 alpha:0.6].CGColor;
    panel.clipsToBounds = YES;
    panel.hidden = YES;
    panel.alpha = 0;
    menuPanel = panel;
    
    UIPanGestureRecognizer *pg = [[UIPanGestureRecognizer alloc] initWithTarget:panel action:@selector(handlePan:)];
    [panel addGestureRecognizer:pg];
    
    CGFloat titleH = 45;
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, titleH)];
    titleBar.backgroundColor = [UIColor colorWithRed:0.12 green:0.06 blue:0.20 alpha:1];
    [panel addSubview:titleBar];
    
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w, titleH)];
    titleLbl.text = @" VRX YEEPS CLIENT ";
    titleLbl.textColor = [UIColor colorWithRed:0.7 green:0.4 blue:0.95 alpha:1];
    titleLbl.font = [UIFont boldSystemFontOfSize:16];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [titleBar addSubview:titleLbl];
    
    VRXBtn *xBtn = [VRXBtn buttonWithType:UIButtonTypeSystem];
    xBtn.frame = CGRectMake(8, 8, 30, 30);
    xBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.12 blue:0.35 alpha:1];
    xBtn.layer.cornerRadius = 6;
    [xBtn setTitle:@"✕" forState:UIControlStateNormal];
    [xBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    xBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    xBtn.action = ^(UIButton *b){ toggleMenu(); };
    [xBtn addTarget:xBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [titleBar addSubview:xBtn];
    
    CGFloat tabBarY = titleH, tabBarH = 36;
    UIView *tabBar = [[UIView alloc] initWithFrame:CGRectMake(0, tabBarY, w, tabBarH)];
    tabBar.backgroundColor = [UIColor colorWithRed:0.15 green:0.08 blue:0.22 alpha:1];
    [panel addSubview:tabBar];
    
    CGFloat third = w / 3.0;
    NSArray *tabTitles = @[@"Player", @"Game", @"Visual"];
    
    for (int i = 0; i < 3; i++) {
        VRXBtn *t = [VRXBtn buttonWithType:UIButtonTypeSystem];
        t.frame = CGRectMake(third*i, 0, third, tabBarH);
        [t setTitle:tabTitles[i] forState:UIControlStateNormal];
        [t setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        t.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        t.backgroundColor = (i == 0) ? tabActiveColor() : tabInactiveColor();
        NSInteger idx = i;
        t.action = ^(UIButton *b){ switchToTab(idx); };
        [t addTarget:t action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
        [tabBar addSubview:t];
        
        if (i == 0) playerTabBtn = t;
        else if (i == 1) gameTabBtn = t;
        else if (i == 2) visualTabBtn = t;
    }
    
    CGFloat contentY = tabBarY + tabBarH, contentH = pH - contentY;
    
    playerTabView = buildPlayerTab(w, contentH);
    playerTabView.frame = CGRectMake(0, contentY, w, contentH);
    [panel addSubview:playerTabView];
    
    gameTabView = buildGameTab(w, contentH);
    gameTabView.frame = CGRectMake(0, contentY, w, contentH);
    gameTabView.hidden = YES;
    [panel addSubview:gameTabView];
    
    visualTabView = buildVisualTab(w, contentH);
    visualTabView.frame = CGRectMake(0, contentY, w, contentH);
    visualTabView.hidden = YES;
    [panel addSubview:visualTabView];
    
    [menuWindow addSubview:panel];
}

static VRXDragButton *toggleBtn;

static void createToggleButton(void) {
    CGRect scr = UIScreen.mainScreen.bounds;
    VRXDragButton *btn = [VRXDragButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(scr.size.width - 62, 120, 52, 52);
    btn.backgroundColor = [UIColor colorWithRed:0.25 green:0.12 blue:0.35 alpha:0.93];
    btn.layer.cornerRadius = 10;
    btn.layer.borderWidth = 1.8;
    btn.layer.borderColor = [UIColor colorWithRed:0.55 green:0.3 blue:0.85 alpha:1].CGColor;
    [btn setTitle:@"☰" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:24];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btn addTarget:btn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:btn action:@selector(handlePan:)];
    [btn addGestureRecognizer:pan];
    
    [menuWindow addSubview:btn];
    toggleBtn = btn;
}

static void setupMenu(void) {
    if (menuWindow) return;
    resolveSymbols();
    
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                menuWindow = [[VRXPassthroughWindow alloc] initWithWindowScene:(UIWindowScene*)s];
                break;
            }
        }
    }
    if (!menuWindow) menuWindow = [[VRXPassthroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    
    menuWindow.windowLevel = UIWindowLevelAlert + 100;
    menuWindow.backgroundColor = UIColor.clearColor;
    menuWindow.userInteractionEnabled = YES;
    menuWindow.rootViewController = [UIViewController new];
    menuWindow.rootViewController.view.backgroundColor = UIColor.clearColor;
    menuWindow.hidden = NO;
    
    createToggleButton();
    createMenuPanel();
}

#pragma mark - Entry Point

__attribute__((constructor)) static void initialize(void) {
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidBecomeActiveNotification
                    object:nil
                    queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *n) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0*NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    setupMenu();
                });
        });
    }];
}
