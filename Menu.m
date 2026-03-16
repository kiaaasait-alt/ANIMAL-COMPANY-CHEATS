extern void vrx_set_halloween(bool state);
extern void vrx_set_thanksgiving(bool state);
extern void vrx_set_snow(bool state);
extern void vrx_set_rain(bool state);
extern void vrx_spawn_monster(const char* monsterType, float x, float y, float z);
extern void vrx_spawn_horde(const char* monsterType, float centerX, float centerY, float centerZ, int count, float radius);

@interface VRXMenu : UIView
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UITextField *airTextField;
@property (nonatomic, strong) UITextField *itemIDField;
@property (nonatomic, strong) UITextField *scaleField;
@property (nonatomic, strong) UITextField *letterSpacingField;
@property (nonatomic, strong) UITextField *axisField;
@property (nonatomic, strong) UITextField *monsterXField;
@property (nonatomic, strong) UITextField *monsterYField;
@property (nonatomic, strong) UITextField *monsterZField;
@property (nonatomic, strong) UITextField *monsterCountField;
@property (nonatomic, strong) UITextField *monsterRadiusField;
@property (nonatomic, strong) NSString *selectedMonster;
@end

@implementation VRXMenu

- (instancetype)init {
    self = [super initWithFrame:[[UIScreen mainScreen] bounds]];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.88];
        self.selectedMonster = @"monster_piranha";
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.scroll = [[UIScrollView alloc] initWithFrame:self.bounds];
    self.scroll.contentSize = CGSizeMake(320, 1250);
    [self addSubview:self.scroll];
    
    self.container = [[UIView alloc] initWithFrame:CGRectMake(20, 40, 280, 1200)];
    self.container.backgroundColor = [UIColor colorWithRed:0.08 green:0.05 blue:0.15 alpha:1];
    self.container.layer.cornerRadius = 12;
    self.container.layer.borderWidth = 1.5;
    self.container.layer.borderColor = [UIColor colorWithRed:0.35 green:0.15 blue:0.55 alpha:0.6].CGColor;
    [self.scroll addSubview:self.container];
    
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 280, 30)];
    header.text = @"✦ VRX CLIENT ✦";
    header.textColor = [UIColor colorWithRed:0.7 green:0.4 blue:0.95 alpha:1];
    header.font = [UIFont boldSystemFontOfSize:18];
    header.textAlignment = NSTextAlignmentCenter;
    [self.container addSubview:header];
    
    int yPos = 55;
    
    yPos = [self addScenerySection:yPos];
    yPos = [self addItemWriterSection:yPos];
    yPos = [self addMonsterSpawnerSection:yPos];
    
    UILabel *footer = [[UILabel alloc] initWithFrame:CGRectMake(0, yPos + 10, 280, 15)];
    footer.text = @"gg/iBaVGKq7U";
    footer.textColor = [UIColor colorWithRed:0.45 green:0.3 blue:0.65 alpha:1];
    footer.font = [UIFont systemFontOfSize:10];
    footer.textAlignment = NSTextAlignmentCenter;
    [self.container addSubview:footer];
    
    self.container.frame = CGRectMake(20, 40, 280, yPos + 35);
    self.scroll.contentSize = CGSizeMake(320, yPos + 85);
}

- (int)addScenerySection:(int)startY {
    UILabel *sceneryLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, startY, 240, 20)];
    sceneryLabel.text = @"SCENERY OVERRIDE";
    sceneryLabel.textColor = [UIColor colorWithRed:0.55 green:0.35 blue:0.75 alpha:1];
    sceneryLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self.container addSubview:sceneryLabel];
    
    NSArray *items = @[
        @{@"icon": @"🎃", @"name": @"Halloween", @"desc": @"Forces Halloween event appearance"},
        @{@"icon": @"🦃", @"name": @"Thanksgiving", @"desc": @"Forces Thanksgiving event appearance"},
        @{@"icon": @"❄️", @"name": @"Snow Storm", @"desc": @"Forces heavy Snow Storm weather"},
        @{@"icon": @"🌧", @"name": @"Heavy Rain", @"desc": @"Forces heavy rain weather"}
    ];
    
    int y = startY + 30;
    for (int i = 0; i < items.count; i++) {
        [self addSceneryRow:items[i] yPos:y tag:i];
        y += 65;
    }
    
    return y;
}

- (void)addSceneryRow:(NSDictionary*)item yPos:(int)y tag:(int)tag {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(15, y, 250, 55)];
    row.backgroundColor = [UIColor colorWithRed:0.06 green:0.04 blue:0.12 alpha:1];
    row.layer.cornerRadius = 8;
    row.layer.borderWidth = 1;
    row.layer.borderColor = [UIColor colorWithRed:0.3 green:0.15 blue:0.5 alpha:0.5].CGColor;
    [self.container addSubview:row];
    
    UILabel *icon = [[UILabel alloc] initWithFrame:CGRectMake(12, 15, 30, 25)];
    icon.text = item[@"icon"];
    icon.font = [UIFont systemFontOfSize:22];
    [row addSubview:icon];
    
    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(50, 8, 140, 20)];
    name.text = item[@"name"];
    name.textColor = [UIColor colorWithRed:0.9 green:0.85 blue:0.95 alpha:1];
    name.font = [UIFont boldSystemFontOfSize:14];
    [row addSubview:name];
    
    UILabel *desc = [[UILabel alloc] initWithFrame:CGRectMake(50, 28, 140, 18)];
    desc.text = item[@"desc"];
    desc.textColor = [UIColor colorWithRed:0.5 green:0.4 blue:0.6 alpha:1];
    desc.font = [UIFont systemFontOfSize:10];
    [row addSubview:desc];
    
    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(195, 12, 51, 31)];
    toggle.tag = tag;
    toggle.onTintColor = [UIColor colorWithRed:0.55 green:0.3 blue:0.85 alpha:1];
    [toggle addTarget:self action:@selector(scenerySwitch:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:toggle];
}

- (int)addItemWriterSection:(int)startY {
    UILabel *writerLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, startY + 10, 250, 25)];
    writerLabel.backgroundColor = [UIColor colorWithRed:0.35 green:0.15 blue:0.5 alpha:1];
    writerLabel.layer.cornerRadius = 6;
    writerLabel.clipsToBounds = YES;
    writerLabel.textColor = [UIColor whiteColor];
    writerLabel.font = [UIFont boldSystemFontOfSize:13];
    writerLabel.textAlignment = NSTextAlignmentCenter;
    writerLabel.text = @"🖊 ITEM WRITER";
    [self.container addSubview:writerLabel];
    
    int y = startY + 45;
    
    y = [self addInputField:@"TEXT TO WRITE IN THE AIR" placeholder:@"vyro" field:&_airTextField yPos:y];
    y = [self addInputField:@"ITEM ID (What to spawn at each pixel)" placeholder:@"item_pelican_case" field:&_itemIDField yPos:y];
    
    y += 10;
    
    y = [self addDualFields:@"SCALE (WHICHISPIXEL)" value1:@"1.0" 
                    label2:@"LETTER SPACING" value2:@"1"
                    field1:&_scaleField field2:&_letterSpacingField yPos:y];
    
    y = [self addInputField:@"WRITE AXIS (X = east/west, Z = north/south)" 
                placeholder:@"X 12 Z 22" field:&_axisField yPos:y];
    
    UIButton *writeBtn = [[UIButton alloc] initWithFrame:CGRectMake(15, y, 250, 42)];
    writeBtn.backgroundColor = [UIColor colorWithRed:0.45 green:0.2 blue:0.7 alpha:1];
    writeBtn.layer.cornerRadius = 8;
    writeBtn.layer.borderWidth = 1;
    writeBtn.layer.borderColor = [UIColor colorWithRed:0.6 green:0.3 blue:0.85 alpha:0.7].CGColor;
    [writeBtn setTitle:@"🖊 WRITE IN THE AIR" forState:UIControlStateNormal];
    [writeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    writeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [writeBtn addTarget:self action:@selector(writeInAir) forControlEvents:UIControlEventTouchUpInside];
    [self.container addSubview:writeBtn];
    
    return y + 52;
}

- (int)addMonsterSpawnerSection:(int)startY {
    UILabel *spawnerLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, startY + 10, 250, 25)];
    spawnerLabel.backgroundColor = [UIColor colorWithRed:0.35 green:0.15 blue:0.5 alpha:1];
    spawnerLabel.layer.cornerRadius = 6;
    spawnerLabel.clipsToBounds = YES;
    spawnerLabel.textColor = [UIColor whiteColor];
    spawnerLabel.font = [UIFont boldSystemFontOfSize:13];
    spawnerLabel.textAlignment = NSTextAlignmentCenter;
    spawnerLabel.text = @"🦈 MONSTER SPAWNER";
    [self.container addSubview:spawnerLabel];
    
    int y = startY + 45;
    
    UILabel *monsterLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 240, 15)];
    monsterLabel.text = @"SELECT MONSTER TYPE";
    monsterLabel.textColor = [UIColor colorWithRed:0.5 green:0.35 blue:0.65 alpha:1];
    monsterLabel.font = [UIFont systemFontOfSize:9];
    [self.container addSubview:monsterLabel];
    
    y += 20;
    
    NSArray *monsters = @[
        @{@"name": @"Piranha", @"id": @"monster_piranha", @"icon": @"🦈"},
        @{@"name": @"Maneater", @"id": @"monster_maneater", @"icon": @"🐊"},
        @{@"name": @"Leech", @"id": @"monster_leech", @"icon": @"🪱"},
        @{@"name": @"Demon", @"id": @"monster_demon", @"icon": @"👹"},
        @{@"name": @"Slime", @"id": @"monster_slime", @"icon": @"🟢"},
        @{@"name": @"Worm", @"id": @"monster_worm", @"icon": @"🐛"},
        @{@"name": @"Spider", @"id": @"monster_spider", @"icon": @"🕷️"},
        @{@"name": @"Mimic", @"id": @"monster_mimic", @"icon": @"📦"}
    ];
    
    for (int i = 0; i < monsters.count; i++) {
        if (i % 2 == 0) {
            [self addMonsterButton:monsters[i] x:15 y:y tag:i];
            if (i + 1 < monsters.count) {
                [self addMonsterButton:monsters[i + 1] x:140 y:y tag:i + 1];
            }
            y += 45;
        }
    }
    
    y += 5;
    
    UILabel *posLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 240, 15)];
    posLabel.text = @"SPAWN COORDINATES";
    posLabel.textColor = [UIColor colorWithRed:0.5 green:0.35 blue:0.65 alpha:1];
    posLabel.font = [UIFont systemFontOfSize:9];
    [self.container addSubview:posLabel];
    
    y += 20;
    
    y = [self addTripleFields:@"X" val1:@"0" label2:@"Y" val2:@"0" label3:@"Z" val3:@"0"
                       field1:&_monsterXField field2:&_monsterYField field3:&_monsterZField yPos:y];
    
    UIButton *getCurrentBtn = [[UIButton alloc] initWithFrame:CGRectMake(15, y, 250, 35)];
    getCurrentBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.12 blue:0.35 alpha:1];
    getCurrentBtn.layer.cornerRadius = 6;
    getCurrentBtn.layer.borderWidth = 1;
    getCurrentBtn.layer.borderColor = [UIColor colorWithRed:0.4 green:0.2 blue:0.5 alpha:0.5].CGColor;
    [getCurrentBtn setTitle:@"📍 USE CURRENT POSITION" forState:UIControlStateNormal];
    [getCurrentBtn setTitleColor:[UIColor colorWithRed:0.7 green:0.6 blue:0.85 alpha:1] forState:UIControlStateNormal];
    getCurrentBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [getCurrentBtn addTarget:self action:@selector(useCurrentPosition) forControlEvents:UIControlEventTouchUpInside];
    [self.container addSubview:getCurrentBtn];
    
    y += 45;
    
    y = [self addDualFields:@"SPAWN COUNT" value1:@"1" 
                    label2:@"HORDE RADIUS" value2:@"5.0"
                    field1:&_monsterCountField field2:&_monsterRadiusField yPos:y];
    
    UIButton *spawnBtn = [[UIButton alloc] initWithFrame:CGRectMake(15, y, 250, 45)];
    spawnBtn.backgroundColor = [UIColor colorWithRed:0.5 green:0.15 blue:0.25 alpha:1];
    spawnBtn.layer.cornerRadius = 8;
    spawnBtn.layer.borderWidth = 1;
    spawnBtn.layer.borderColor = [UIColor colorWithRed:0.7 green:0.2 blue:0.35 alpha:0.7].CGColor;
    [spawnBtn setTitle:@"🦈 SPAWN MONSTERS" forState:UIControlStateNormal];
    [spawnBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    spawnBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [spawnBtn addTarget:self action:@selector(spawnMonsters) forControlEvents:UIControlEventTouchUpInside];
    [self.container addSubview:spawnBtn];
    
    return y + 55;
}

- (void)addMonsterButton:(NSDictionary*)monster x:(int)x y:(int)y tag:(int)tag {
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(x, y, 115, 35)];
    btn.backgroundColor = [UIColor colorWithRed:0.06 green:0.04 blue:0.12 alpha:1];
    btn.layer.cornerRadius = 6;
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [UIColor colorWithRed:0.3 green:0.15 blue:0.5 alpha:0.5].CGColor;
    btn.tag = tag;
    
    NSString *title = [NSString stringWithFormat:@"%@ %@", monster[@"icon"], monster[@"name"]];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor colorWithRed:0.85 green:0.8 blue:0.95 alpha:1] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:12];
    
    [btn addTarget:self action:@selector(monsterSelected:) forControlEvents:UIControlEventTouchUpInside];
    [self.container addSubview:btn];
}

- (int)addInputField:(NSString*)label placeholder:(NSString*)ph field:(UITextField**)fieldPtr yPos:(int)y {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 240, 15)];
    lbl.text = label;
    lbl.textColor = [UIColor colorWithRed:0.5 green:0.35 blue:0.65 alpha:1];
    lbl.font = [UIFont systemFontOfSize:9];
    [self.container addSubview:lbl];
    
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(15, y + 18, 250, 38)];
    field.backgroundColor = [UIColor colorWithRed:0.06 green:0.04 blue:0.12 alpha:1];
    field.layer.cornerRadius = 6;
    field.layer.borderWidth = 1;
    field.layer.borderColor = [UIColor colorWithRed:0.3 green:0.15 blue:0.5 alpha:0.5].CGColor;
    field.textColor = [UIColor colorWithRed:0.85 green:0.8 blue:0.95 alpha:1];
    field.font = [UIFont systemFontOfSize:13];
    field.placeholder = ph;
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:ph 
        attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:0.3 green:0.2 blue:0.4 alpha:1]}];
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 38)];
    field.leftViewMode = UITextFieldViewModeAlways;
    [self.container addSubview:field];
    
    *fieldPtr = field;
    return y + 63;
}

- (int)addDualFields:(NSString*)label1 value1:(NSString*)val1
              label2:(NSString*)label2 value2:(NSString*)val2
              field1:(UITextField**)f1 field2:(UITextField**)f2 yPos:(int)y {
    
    UILabel *lbl1 = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 110, 15)];
    lbl1.text = label1;
    lbl1.textColor = [UIColor colorWithRed:0.5 green:0.35 blue:0.65 alpha:1];
    lbl1.font = [UIFont systemFontOfSize:9];
    [self.container addSubview:lbl1];
    
    UILabel *lbl2 = [[UILabel alloc] initWithFrame:CGRectMake(150, y, 110, 15)];
    lbl2.text = label2;
    lbl2.textColor = [UIColor colorWithRed:0.5 green:0.35 blue:0.65 alpha:1];
    lbl2.font = [UIFont systemFontOfSize:9];
    [self.container addSubview:lbl2];
    
    UITextField *field1 = [[UITextField alloc] initWithFrame:CGRectMake(15, y + 18, 115, 38)];
    field1.backgroundColor = [UIColor colorWithRed:0.06 green:0.04 blue:0.12 alpha:1];
    field1.layer.cornerRadius = 6;
    field1.layer.borderWidth = 1;
    field1.layer.borderColor = [UIColor colorWithRed:0.3 green:0.15 blue:0.5 alpha:0.5].CGColor;
    field1.textColor = [UIColor colorWithRed:0.85 green:0.8 blue:0.95 alpha:1];
    field1.font = [UIFont systemFontOfSize:13];
    field1.text = val1;
    field1.textAlignment = NSTextAlignmentCenter;
    [self.container addSubview:field1];
    
    UITextField *field2 = [[UITextField alloc] initWithFrame:CGRectMake(150, y + 18, 115, 38)];
    field2.backgroundColor = [UIColor colorWithRed:0.06 green:0.04 blue:0.12 alpha:1];
    field2.layer.cornerRadius = 6;
    field2.layer.borderWidth = 1;
    field2.layer.borderColor = [UIColor colorWithRed:0.3 green:0.15 blue:0.5 alpha:0.5].CGColor;
    field2.textColor = [UIColor colorWithRed:0.85 green:0.8 blue:0.95 alpha:1];
    field2.font = [UIFont systemFontOfSize:13];
    field2.text = val2;
    field2.textAlignment = NSTextAlignmentCenter;
    [self.container addSubview:field2];
    
    *f1 = field1;
    *f2 = field2;
    return y + 63;
}

- (int)addTripleFields:(NSString*)l1 val1:(NSString*)v1 label2:(NSString*)l2 val2:(NSString*)v2 
                label3:(NSString*)l3 val3:(NSString*)v3
                field1:(UITextField**)f1 field2:(UITextField**)f2 field3:(UITextField**)f3 yPos:(int)y {
    
    UILabel *lbl1 = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 70, 15)];
    lbl1.text = l1;
    lbl1.textColor = [UIColor colorWithRed:0.5 green:0.35 blue:0.65 alpha:1];
    lbl1.font = [UIFont systemFontOfSize:9];
    [self.container addSubview:lbl1];
    
    UILabel *lbl2 = [[UILabel alloc] initWithFrame:CGRectMake(105, y, 70, 15)];
    lbl2.text = l2;
    lbl2.textColor = [UIColor colorWithRed:0.5 green:0.35 blue:0.65 alpha:1];
    lbl2.font = [UIFont systemFontOfSize:9];
    [self.container addSubview:lbl2];
    
    UILabel *lbl3 = [[UILabel alloc] initWithFrame:CGRectMake(190, y, 70, 15)];
    lbl3.text = l3;
    lbl3.textColor = [UIColor colorWithRed:0.5 green:0.35 blue:0.65 alpha:1];
    lbl3.font = [UIFont systemFontOfSize:9];
    [self.container addSubview:lbl3];
    
    UITextField *field1 = [[UITextField alloc] initWithFrame:CGRectMake(15, y + 18, 75, 38)];
    field1.backgroundColor = [UIColor colorWithRed:0.06 green:0.04 blue:0.12 alpha:1];
    field1.layer.cornerRadius = 6;
    field1.layer.borderWidth = 1;
    field1.layer.borderColor = [UIColor colorWithRed:0.3 green:0.15 blue:0.5 alpha:0.5].CGColor;
    field1.textColor = [UIColor colorWithRed:0.85 green:0.8 blue:0.95 alpha:1];
    field1.font = [UIFont systemFontOfSize:13];
    field1.text = v1;
    field1.textAlignment = NSTextAlignmentCenter;
    [self.container addSubview:field1];
    
    UITextField *field2 = [[UITextField alloc] initWithFrame:CGRectMake(100, y + 18, 75, 38)];
    field2.backgroundColor = [UIColor colorWithRed:0.06 green:0.04 blue:0.12 alpha:1];
    field2.layer.cornerRadius = 6;
    field2.layer.borderWidth = 1;
    field2.layer.borderColor = [UIColor colorWithRed:0.3 green:0.15 blue:0.5 alpha:0.5].CGColor;
    field2.textColor = [UIColor colorWithRed:0.85 green:0.8 blue:0.95 alpha:1];
    field2.font = [UIFont systemFontOfSize:13];
    field2.text = v2;
    field2.textAlignment = NSTextAlignmentCenter;
    [self.container addSubview:field2];
    
    UITextField *field3 = [[UITextField alloc] initWithFrame:CGRectMake(185, y + 18, 75, 38)];
    field3.backgroundColor = [UIColor colorWithRed:0.06 green:0.04 blue:0.12 alpha:1];
    field3.layer.cornerRadius = 6;
    field3.layer.borderWidth = 1;
    field3.layer.borderColor = [UIColor colorWithRed:0.3 green:0.15 blue:0.5 alpha:0.5].CGColor;
    field3.textColor = [UIColor colorWithRed:0.85 green:0.8 blue:0.95 alpha:1];
    field3.font = [UIFont systemFontOfSize:13];
    field3.text = v3;
    field3.textAlignment = NSTextAlignmentCenter;
    [self.container addSubview:field3];
    
    *f1 = field1;
    *f2 = field2;
    *f3 = field3;
    return y + 63;
}

- (void)scenerySwitch:(UISwitch*)s {
    switch(s.tag) {
        case 0: vrx_set_halloween(s.on); break;
        case 1: vrx_set_thanksgiving(s.on); break;
        case 2: vrx_set_snow(s.on); break;
        case 3: vrx_set_rain(s.on); break;
    }
}

- (void)writeInAir {
    NSString *text = self.airTextField.text ?: @"VRX";
    NSString *itemID = self.itemIDField.text ?: @"item_pelican_case";
    float scale = [self.scaleField.text floatValue] ?: 1.0f;
    int spacing = [self.letterSpacingField.text intValue] ?: 1;
    NSString *axis = self.axisField.text ?: @"X 12 Z 22";
    
    NSLog(@"[VRX] Writing '%@' with item '%@' at scale %.1f spacing %d axis %@", 
          text, itemID, scale, spacing, axis);
}

- (void)monsterSelected:(UIButton*)sender {
    NSArray *monsterIDs = @[@"monster_piranha", @"monster_maneater", @"monster_leech", @"monster_demon", 
                            @"monster_slime", @"monster_worm", @"monster_spider", @"monster_mimic"];
    
    if (sender.tag < monsterIDs.count) {
        self.selectedMonster = monsterIDs[sender.tag];
        
        for (UIView *subview in self.container.subviews) {
            if ([subview isKindOfClass:[UIButton class]]) {
                UIButton *btn = (UIButton*)subview;
                if (btn.tag < monsterIDs.count && btn != sender) {
                    btn.layer.borderColor = [UIColor colorWithRed:0.3 green:0.15 blue:0.5 alpha:0.5].CGColor;
                    btn.layer.borderWidth = 1;
                }
            }
        }
        
        sender.layer.borderColor = [UIColor colorWithRed:0.7 green:0.4 blue:0.95 alpha:1].CGColor;
        sender.layer.borderWidth = 2;
        
        NSLog(@"[VRX] Selected monster: %@", self.selectedMonster);
    }
}

- (void)useCurrentPosition {
    self.monsterXField.text = @"12.5";
    self.monsterYField.text = @"0.0";
    self.monsterZField.text = @"22.3";
}

- (void)spawnMonsters {
    float x = [self.monsterXField.text floatValue];
    float y = [self.monsterYField.text floatValue];
    float z = [self.monsterZField.text floatValue];
    int count = [self.monsterCountField.text intValue] ?: 1;
    float radius = [self.monsterRadiusField.text floatValue] ?: 5.0f;
    
    if (count == 1) {
        vrx_spawn_monster([self.selectedMonster UTF8String], x, y, z);
    } else {
        vrx_spawn_horde([self.selectedMonster UTF8String], x, y, z, count, radius);
    }
}

@end
