@interface VRXMenu : UIView
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) UIScrollView *scroll;
@end

@implementation VRXMenu

- (id)init {
    self = [super initWithFrame:[[UIScreen mainScreen] bounds]];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.88];
        [self buildGUI];
    }
    return self;
}

- (void)buildGUI {
    self.scroll = [[UIScrollView alloc] initWithFrame:self.bounds];
    self.scroll.contentSize = CGSizeMake(320, 600);
    [self addSubview:self.scroll];
    
    self.container = [[UIView alloc] initWithFrame:CGRectMake(20, 40, 280, 550)];
    self.container.backgroundColor = [UIColor colorWithRed:0.08 green:0.05 blue:0.15 alpha:1];
    self.container.layer.cornerRadius = 12;
    self.container.layer.borderWidth = 1.5;
    self.container.layer.borderColor = [UIColor colorWithRed:0.35 green:0.15 blue:0.55 alpha:0.6].CGColor;
    [self.scroll addSubview:self.container];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 280, 35)];
    title.text = @"✦ VRX YEEPS CLIENT ✦";
    title.textColor = [UIColor colorWithRed:0.7 green:0.4 blue:0.95 alpha:1];
    title.font = [UIFont boldSystemFontOfSize:18];
    title.textAlignment = NSTextAlignmentCenter;
    [self.container addSubview:title];
    
    int y = 60;
    y = [self addPlayerSection:y];
    y = [self addGameSection:y];
    y = [self addVisualSection:y];
    
    UILabel *footer = [[UILabel alloc] initWithFrame:CGRectMake(0, y + 10, 280, 15)];
    footer.text = @"VRX Mods";
    footer.textColor = [UIColor colorWithRed:0.45 green:0.3 blue:0.65 alpha:1];
    footer.font = [UIFont systemFontOfSize:10];
    footer.textAlignment = NSTextAlignmentCenter;
    [self.container addSubview:footer];
    
    self.container.frame = CGRectMake(20, 40, 280, y + 35);
    self.scroll.contentSize = CGSizeMake(320, y + 85);
}

- (int)addPlayerSection:(int)yStart {
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(15, yStart, 250, 25)];
    header.backgroundColor = [UIColor colorWithRed:0.35 green:0.15 blue:0.5 alpha:1];
    header.layer.cornerRadius = 6;
    header.clipsToBounds = YES;
    header.textColor = [UIColor whiteColor];
    header.font = [UIFont boldSystemFontOfSize:13];
    header.textAlignment = NSTextAlignmentCenter;
    header.text = @"🏃 PLAYER MODS";
    [self.container addSubview:header];
    
    int y = yStart + 35;
    
    NSDictionary *mods[] = {
        @{@"icon": @"⚡", @"name": @"Speed Boost", @"desc": @"Increase movement speed"},
        @{@"icon": @"🦘", @"name": @"Super Jump", @"desc": @"Jump higher than normal"},
        @{@"icon": @"👻", @"name": @"No Clip", @"desc": @"Walk through walls"}
    };
    
    for (int i = 0; i < 3; i++) {
        [self makeToggleRow:mods[i] at:y tag:i];
        y += 60;
    }
    
    return y + 10;
}

- (int)addGameSection:(int)yStart {
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(15, yStart, 250, 25)];
    header.backgroundColor = [UIColor colorWithRed:0.35 green:0.15 blue:0.5 alpha:1];
    header.layer.cornerRadius = 6;
    header.clipsToBounds = YES;
    header.textColor = [UIColor whiteColor];
    header.font = [UIFont boldSystemFontOfSize:13];
    header.textAlignment = NSTextAlignmentCenter;
    header.text = @"🎮 GAME MODS";
    [self.container addSubview:header];
    
    int y = yStart + 35;
    
    NSDictionary *mods[] = {
        @{@"icon": @"🌟", @"name": @"Infinite Lives", @"desc": @"Never lose a life"},
        @{@"icon": @"⏱️", @"name": @"Freeze Timer", @"desc": @"Stop the countdown timer"}
    };
    
    for (int i = 0; i < 2; i++) {
        [self makeToggleRow:mods[i] at:y tag:i + 10];
        y += 60;
    }
    
    return y + 10;
}

- (int)addVisualSection:(int)yStart {
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(15, yStart, 250, 25)];
    header.backgroundColor = [UIColor colorWithRed:0.35 green:0.15 blue:0.5 alpha:1];
    header.layer.cornerRadius = 6;
    header.clipsToBounds = YES;
    header.textColor = [UIColor whiteColor];
    header.font = [UIFont boldSystemFontOfSize:13];
    header.textAlignment = NSTextAlignmentCenter;
    header.text = @"👁️ VISUAL MODS";
    [self.container addSubview:header];
    
    int y = yStart + 35;
    
    NSDictionary *mods[] = {
        @{@"icon": @"🌈", @"name": @"RGB Mode", @"desc": @"Rainbow color effects"},
        @{@"icon": @"🔦", @"name": @"Full Bright", @"desc": @"Remove all darkness"}
    };
    
    for (int i = 0; i < 2; i++) {
        [self makeToggleRow:mods[i] at:y tag:i + 20];
        y += 60;
    }
    
    return y;
}

- (void)makeToggleRow:(NSDictionary*)mod at:(int)y tag:(int)tag {
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(15, y, 250, 50)];
    box.backgroundColor = [UIColor colorWithRed:0.06 green:0.04 blue:0.12 alpha:1];
    box.layer.cornerRadius = 8;
    box.layer.borderWidth = 1;
    box.layer.borderColor = [UIColor colorWithRed:0.3 green:0.15 blue:0.5 alpha:0.5].CGColor;
    [self.container addSubview:box];
    
    UILabel *icon = [[UILabel alloc] initWithFrame:CGRectMake(12, 12, 26, 26)];
    icon.text = mod[@"icon"];
    icon.font = [UIFont systemFontOfSize:20];
    [box addSubview:icon];
    
    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(45, 8, 140, 18)];
    name.text = mod[@"name"];
    name.textColor = [UIColor colorWithRed:0.9 green:0.85 blue:0.95 alpha:1];
    name.font = [UIFont boldSystemFontOfSize:13];
    [box addSubview:name];
    
    UILabel *desc = [[UILabel alloc] initWithFrame:CGRectMake(45, 26, 140, 16)];
    desc.text = mod[@"desc"];
    desc.textColor = [UIColor colorWithRed:0.5 green:0.4 blue:0.6 alpha:1];
    desc.font = [UIFont systemFontOfSize:9];
    [box addSubview:desc];
    
    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(195, 9, 51, 31)];
    toggle.tag = tag;
    toggle.onTintColor = [UIColor colorWithRed:0.55 green:0.3 blue:0.85 alpha:1];
    [toggle addTarget:self action:@selector(modToggled:) forControlEvents:UIControlEventValueChanged];
    [box addSubview:toggle];
}

- (void)modToggled:(UISwitch*)sw {
    NSLog(@"[VRX] Mod %d toggled: %@", (int)sw.tag, sw.on ? @"ON" : @"OFF");
    
    // Hook implementations go here based on tag
    switch(sw.tag) {
        case 0: // Speed boost
            break;
        case 1: // Super jump
            break;
        case 2: // No clip
            break;
        case 10: // Infinite lives
            break;
        case 11: // Freeze timer
            break;
        case 20: // RGB mode
            break;
        case 21: // Full bright
            break;
    }
}

@end
