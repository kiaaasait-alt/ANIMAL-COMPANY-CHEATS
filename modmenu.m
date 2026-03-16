#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <sys/mman.h>
#import <libkern/OSCacheControl.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <os/log.h>

// ─────────────────────────────────────────
// Animal Company – Vyro Client V2 (Improved)
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

// Bitmap font type - must be defined before forward declarations
typedef struct { uint8_t col[5]; } Glyph5x7;

#pragma mark - Constants

static const NSTimeInterval kSpawnRetryDelay = 2.0;
static const NSTimeInterval kCameraPollInterval = 0.25;
static const NSTimeInterval kSpawnThreadSleep = 0.06;
static const CGFloat kMenuAnimationDuration = 0.22;
static const NSUInteger kMaxCameraLogEntries = 8;
static const NSUInteger kMaxSpawnRetries __attribute__((unused)) = 3;

// Grid dimensions
#define GRID_COLS 10
#define GRID_ROWS 10

// RVAs for scenery patches
#define RVA_isHalloween    0x17718CC
#define RVA_isThanksgiving 0x177190C
#define RVA_isSnowStorm    0x177194C
#define RVA_isHeavyRain    0x17719B4

#pragma mark - Il2Cpp API Function Pointers

static Il2CppDomain*   (*_il2cpp_domain_get)(void)                                              = NULL;
static Il2CppAssembly* (*_il2cpp_domain_assembly_open)(Il2CppDomain*, const char*)              = NULL;
static Il2CppImage*    (*_il2cpp_assembly_get_image)(Il2CppAssembly*)                           = NULL;
static Il2CppClass*    (*_il2cpp_class_from_name)(Il2CppImage*, const char*, const char*)       = NULL;
static Il2CppMethod*   (*_il2cpp_class_get_method_from_name)(Il2CppClass*, const char*, int)    = NULL;
static Il2CppObject*   (*_il2cpp_runtime_invoke)(Il2CppMethod*, void*, void**, Il2CppObject**)  = NULL;
static Il2CppString*   (*_il2cpp_string_new)(const char*)                                       = NULL;
static Il2CppObject*   (*_il2cpp_object_new)(Il2CppClass*)                                     = NULL;
static Il2CppField*    (*_il2cpp_class_get_field_from_name)(Il2CppClass*, const char*)          = NULL;
static void            (*_il2cpp_field_static_get_value)(Il2CppField*, void*)                   = NULL;
static Il2CppObject*   (*_il2cpp_object_unbox)(Il2CppObject*)                                   = NULL;
static void            (*_il2cpp_field_set_value)(Il2CppObject*, Il2CppField*, void*)           = NULL;

#pragma mark - State Management

static BOOL _resolved = NO;
static dispatch_once_t _resolveOnceToken;

// UI Elements
static UILabel        *statusLabel;
static UITextField    *idField;
static UITextField    *xField;
static UITextField    *yField;
static UITextField    *zField;
static UILabel        *qtyLabel;
static UIPickerView   *idPicker;
static UIView         *pickerCard;
static NSMutableArray<NSValue *> *jsonIDs;

static UITextField    *mobIDField;
static UITextField    *mobRadiusField;
static UIView         *mobTabView;

static UIView         *cameraTabView;
static UILabel        *camPosLabel;
static UILabel        *camLogLabel;
static UIButton       *camTrackBtn;
static NSTimer        *camTimer;
static BOOL            camTracking = NO;

static UIView         *sceneryTabView;

static BOOL sceneryHalloween    = NO;
static BOOL sceneryThanksgiving = NO;
static BOOL scenerySnowStorm    = NO;
static BOOL sceneryHeavyRain    = NO;

static float spawnX;
static float spawnY;
static float spawnZ;

static UIWindow  *menuWindow;
static UIView    *menuPanel;
static BOOL       menuVisible;

static UIView    *itemsTabView;
static UIView    *settingsTabView;
static UIButton  *itemsTabBtn;
static UIButton  *settingsTabBtn;
static UIButton  *mobTabBtn;
static UIButton  *cameraTabBtn;
static UIButton  *sceneryTabBtn;

static NSInteger  spawnQty    = 1;

static BOOL       fartyEnabled = NO;
static UIButton  *fartyBtn     = nil;

// Spam toggles
static BOOL       yeetSpamEnabled = NO;
static UIButton  *yeetSpamBtn    = nil;
static NSTimer   *yeetSpamTimer  = nil;

static BOOL       killSpamEnabled = NO;
static UIButton  *killSpamBtn    = nil;
static NSTimer   *killSpamTimer  = nil;

static NSInteger  displayMode  = 0;
static NSInteger  _currentTabIndex = 0;

// Writer tab globals
static UIView         *writerTabView;
static UIButton       *writerTabBtn;
static UITextField    *writerTextField;
static UITextField    *writerItemIDField;
static UITextField    *writerScaleField;
static UITextField    *writerSpacingField;
static UITextField    *writerAxisField;
static UILabel        *writerStatusLabel;
static UILabel        *writerPreviewLabel;

// Grid painter
static BOOL            gridCells[GRID_ROWS][GRID_COLS];
static UIButton       *gridButtons[GRID_ROWS][GRID_COLS];
static UITextField    *gridItemIDField;
static UITextField    *gridScaleField;

// Camera log
static NSMutableArray<NSString *> *camLog;

#pragma mark - Spawn Queue

typedef struct {
    NSString *itemID;
    float     hue;
    BOOL      networked;
    NSInteger qty;
} PendingSpawn;

static NSMutableArray<NSValue *> *spawnQueue = nil;
static dispatch_queue_t spawnQueueLock;

#pragma mark - Forward Declarations

static NSString *doSpawnItem(NSString *itemID, float hue, BOOL networked);
static void spawnItemWithHue(NSString *itemID, float hue);
static void spawnItemAsyncWithHue(NSString *itemID, float hue);
static void applyDisplayMode(NSInteger mode);
static void updateWriterPreview(void);
static void setStatus(NSString *msg, BOOL good);
static void toggleMenu(void);
static void readSpawnPosition(void);
static void resolveSymbols(void);
static Il2CppImage *getACImage(void);
static Il2CppObject *getAppState(Il2CppImage *image);
static BOOL invokeAction(const char *actionClassName, void **ctorArgs, int ctorArgCount, NSString **outError);
static Il2CppObject *resolveSingleton(Il2CppImage *image, const char *ns, const char *className);
static Il2CppMethod *probeMethod(Il2CppClass *klass, const char *name, int minArgs, int maxArgs);
static Il2CppClass *getPrefabGeneratorClass(void);
static Il2CppObject *getPrefabGeneratorInstance(void);
static void enqueueSpawn(NSString *itemID, float hue, BOOL networked, NSInteger qty);
static void spawnMobNearbyPlayer(NSString *mobIDStr, float radius);
static Vector3 getCameraPosition(void);
static void pollCameraPosition(void);
static void startCameraTracking(void);
static void stopCameraTracking(void);
static void setFarty(BOOL enabled);
static void startYeetSpam(BOOL enabled);
static void startKillSpam(BOOL enabled);
static NSArray *parseJSON(NSData *data);
static void spawnTextInWorld(NSString *text, NSString *itemID, float originX, float originY, float originZ, float scale, float letterSpacing, int axis);
static void spawnGridPattern(NSString *itemID, float originX, float originY, float originZ, float scale, int axis);
static const Glyph5x7 *glyphForChar(unichar c);
static NSInteger pixelCountForString(NSString *text);
static NSString *asciiPreviewForString(NSString *text);
static void openJSONPicker(void);
static UIScrollView *buildWriterTab(CGFloat w, CGFloat h);
static UIScrollView *buildItemsTab(CGFloat w, CGFloat h);
static UIScrollView *buildMobsTab(CGFloat w, CGFloat h);
static UIScrollView *buildCameraTab(CGFloat w, CGFloat h);
static UIScrollView *buildSceneryTab(CGFloat w, CGFloat h);
static UIScrollView *buildSettingsTab(CGFloat w, CGFloat h);
static void createMenuPanel(void);
static void createToggleButton(void);
static void setupMenu(void);
static void relayoutMenuForBounds(CGRect scr);
static void switchToTab(NSInteger tab);

#pragma mark - Logging

#define VYRO_LOG(fmt, ...) os_log(OS_LOG_DEFAULT, "[VyroClient] " fmt, ##__VA_ARGS__)
#define VYRO_ERROR(fmt, ...) os_log_error(OS_LOG_DEFAULT, "[VyroClient] ERROR: " fmt, ##__VA_ARGS__)

#pragma mark - Bitmap Font Data

static const Glyph5x7 kFont5x7[] = {
    {{0x00,0x00,0x00,0x00,0x00}}, // ' ' (32)
    {{0x00,0x00,0x5F,0x00,0x00}}, // '!' (33)
    {{0x00,0x07,0x00,0x07,0x00}}, // '"' (34)
    {{0x14,0x7F,0x14,0x7F,0x14}}, // '#' (35)
    {{0x24,0x2A,0x7F,0x2A,0x12}}, // '$' (36)
    {{0x23,0x13,0x08,0x64,0x62}}, // '%' (37)
    {{0x36,0x49,0x55,0x22,0x50}}, // '&' (38)
    {{0x00,0x05,0x03,0x00,0x00}}, // ''' (39)
    {{0x00,0x1C,0x22,0x41,0x00}}, // '(' (40)
    {{0x00,0x41,0x22,0x1C,0x00}}, // ')' (41)
    {{0x14,0x08,0x3E,0x08,0x14}}, // '*' (42)
    {{0x08,0x08,0x3E,0x08,0x08}}, // '+' (43)
    {{0x00,0x50,0x30,0x00,0x00}}, // ',' (44)
    {{0x08,0x08,0x08,0x08,0x08}}, // '-' (45)
    {{0x00,0x60,0x60,0x00,0x00}}, // '.' (46)
    {{0x20,0x10,0x08,0x04,0x02}}, // '/' (47)
    {{0x3E,0x51,0x49,0x45,0x3E}}, // '0' (48)
    {{0x00,0x42,0x7F,0x40,0x00}}, // '1' (49)
    {{0x42,0x61,0x51,0x49,0x46}}, // '2' (50)
    {{0x21,0x41,0x45,0x4B,0x31}}, // '3' (51)
    {{0x18,0x14,0x12,0x7F,0x10}}, // '4' (52)
    {{0x27,0x45,0x45,0x45,0x39}}, // '5' (53)
    {{0x3C,0x4A,0x49,0x49,0x30}}, // '6' (54)
    {{0x01,0x71,0x09,0x05,0x03}}, // '7' (55)
    {{0x36,0x49,0x49,0x49,0x36}}, // '8' (56)
    {{0x06,0x49,0x49,0x29,0x1E}}, // '9' (57)
    {{0x00,0x36,0x36,0x00,0x00}}, // ':' (58)
    {{0x00,0x56,0x36,0x00,0x00}}, // ';' (59)
    {{0x08,0x14,0x22,0x41,0x00}}, // '<' (60)
    {{0x14,0x14,0x14,0x14,0x14}}, // '=' (61)
    {{0x00,0x41,0x22,0x14,0x08}}, // '>' (62)
    {{0x02,0x01,0x51,0x09,0x06}}, // '?' (63)
    {{0x32,0x49,0x79,0x41,0x3E}}, // '@' (64)
    {{0x7E,0x09,0x09,0x09,0x7E}}, // 'A' (65)
    {{0x7F,0x49,0x49,0x49,0x36}}, // 'B' (66)
    {{0x3E,0x41,0x41,0x41,0x22}}, // 'C' (67)
    {{0x7F,0x41,0x41,0x22,0x1C}}, // 'D' (68)
    {{0x7F,0x49,0x49,0x49,0x41}}, // 'E' (69)
    {{0x7F,0x09,0x09,0x09,0x01}}, // 'F' (70)
    {{0x3E,0x41,0x49,0x49,0x7A}}, // 'G' (71)
    {{0x7F,0x08,0x08,0x08,0x7F}}, // 'H' (72)
    {{0x00,0x41,0x7F,0x41,0x00}}, // 'I' (73)
    {{0x20,0x40,0x41,0x3F,0x01}}, // 'J' (74)
    {{0x7F,0x08,0x14,0x22,0x41}}, // 'K' (75)
    {{0x7F,0x40,0x40,0x40,0x40}}, // 'L' (76)
    {{0x7F,0x02,0x04,0x02,0x7F}}, // 'M' (77)
    {{0x7F,0x04,0x08,0x10,0x7F}}, // 'N' (78)
    {{0x3E,0x41,0x41,0x41,0x3E}}, // 'O' (79)
    {{0x7F,0x09,0x09,0x09,0x06}}, // 'P' (80)
    {{0x3E,0x41,0x51,0x21,0x5E}}, // 'Q' (81)
    {{0x7F,0x09,0x19,0x29,0x46}}, // 'R' (82)
    {{0x46,0x49,0x49,0x49,0x31}}, // 'S' (83)
    {{0x01,0x01,0x7F,0x01,0x01}}, // 'T' (84)
    {{0x3F,0x40,0x40,0x40,0x3F}}, // 'U' (85)
    {{0x1F,0x20,0x40,0x20,0x1F}}, // 'V' (86)
    {{0x7F,0x20,0x18,0x20,0x7F}}, // 'W' (87)
    {{0x63,0x14,0x08,0x14,0x63}}, // 'X' (88)
    {{0x03,0x04,0x78,0x04,0x03}}, // 'Y' (89)
    {{0x61,0x51,0x49,0x45,0x43}}, // 'Z' (90)
};

#pragma mark - UI Helpers

static void setStatus(NSString *msg, BOOL good) {
    if (!msg) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!statusLabel) return;
        statusLabel.text = msg;
        statusLabel.textColor = good
            ? [UIColor colorWithRed:0.45 green:0.90 blue:0.55 alpha:1]
            : [UIColor colorWithRed:1.00 green:0.42 blue:0.35 alpha:1];
    });
}

static void toggleMenu(void) {
    menuVisible = !menuVisible;
    [UIView animateWithDuration:kMenuAnimationDuration
                     animations:^{ 
                         if (menuPanel) menuPanel.alpha = menuVisible ? 1.0 : 0.0; 
                     }
                     completion:^(BOOL finished){ 
                         if (menuPanel) menuPanel.hidden = !menuVisible; 
                     }];
}

static void readSpawnPosition(void) {
    @try {
        if (xField) spawnX = (float)[xField.text floatValue];
        if (yField) spawnY = (float)[yField.text floatValue];
        if (zField) spawnZ = (float)[zField.text floatValue];
    } @catch (NSException *exception) {
        VYRO_ERROR("Exception reading spawn position: %{public}@", exception);
    }
}

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
        if (!fw) { 
            VYRO_ERROR("UnityFramework not found.");
            return; 
        }

        #define RESOLVE(fn) do { \
            _##fn = dlsym(fw, #fn); \
            if (_##fn) { \
                VYRO_LOG("%s -> %p", #fn, _##fn); \
            } else { \
                VYRO_ERROR("%s not found", #fn); \
            } \
        } while(0)
        
        RESOLVE(il2cpp_domain_get);
        RESOLVE(il2cpp_domain_assembly_open);
        RESOLVE(il2cpp_assembly_get_image);
        RESOLVE(il2cpp_class_from_name);
        RESOLVE(il2cpp_class_get_method_from_name);
        RESOLVE(il2cpp_runtime_invoke);
        RESOLVE(il2cpp_string_new);
        RESOLVE(il2cpp_object_new);
        RESOLVE(il2cpp_class_get_field_from_name);
        RESOLVE(il2cpp_field_static_get_value);
        RESOLVE(il2cpp_field_set_value);
        RESOLVE(il2cpp_object_unbox);
        #undef RESOLVE

        _resolved = (_il2cpp_domain_get && _il2cpp_domain_assembly_open &&
                     _il2cpp_assembly_get_image && _il2cpp_class_from_name &&
                     _il2cpp_class_get_method_from_name && _il2cpp_runtime_invoke &&
                     _il2cpp_string_new && _il2cpp_object_new);

        VYRO_LOG("resolved: %{public}@", _resolved ? @"YES" : @"NO");
        
        // Initialize spawn queue lock
        spawnQueueLock = dispatch_queue_create("com.vyroclient.spawnqueue", DISPATCH_QUEUE_SERIAL);
    });
}

static Il2CppImage *getACImage(void) {
    if (!_il2cpp_domain_get) return NULL;
    Il2CppDomain *domain = _il2cpp_domain_get();
    if (!domain) return NULL;
    
    Il2CppAssembly *assembly = _il2cpp_domain_assembly_open(domain, "AnimalCompany");
    if (!assembly)
        assembly = _il2cpp_domain_assembly_open(domain, "Assembly-CSharp");
    if (!assembly) return NULL;
    
    return _il2cpp_assembly_get_image(assembly);
}

static Il2CppObject *getAppState(Il2CppImage *image) {
    if (!image || !_il2cpp_class_from_name) return NULL;
    
    Il2CppClass *klass = _il2cpp_class_from_name(image, "AnimalCompany", "AppState");
    if (!klass) klass = _il2cpp_class_from_name(image, "", "AppState");
    if (!klass) return NULL;
    
    static const char *getterNames[] = {
        "get_Instance", "GetInstance", "get_Current",
        "get_Singleton", "GetSingleton", "get_instance", NULL
    };
    
    for (int i = 0; getterNames[i]; i++) {
        if (!_il2cpp_class_get_method_from_name) break;
        Il2CppMethod *getter = _il2cpp_class_get_method_from_name(klass, getterNames[i], 0);
        if (!getter) continue;
        
        Il2CppObject *exc = NULL;
        Il2CppObject *inst = _il2cpp_runtime_invoke(getter, NULL, NULL, &exc);
        if (inst && !exc) {
            VYRO_LOG("AppState singleton via %s -> %p", getterNames[i], inst);
            return inst;
        }
    }
    return NULL;
}

static BOOL invokeAction(const char *actionClassName,
                         void **ctorArgs, 
                         int ctorArgCount,
                         NSString **outError) {
    if (!_resolved) { 
        if (outError) *outError = @"Il2Cpp not resolved"; 
        return NO; 
    }
    
    Il2CppImage *image = getACImage();
    if (!image) { 
        if (outError) *outError = @"AnimalCompany image not found"; 
        return NO; 
    }

    Il2CppClass *klass = _il2cpp_class_from_name(image, "AnimalCompany", actionClassName);
    if (!klass) klass = _il2cpp_class_from_name(image, "", actionClassName);
    if (!klass) {
        if (outError) *outError = [NSString stringWithFormat:@"class %s not found", actionClassName];
        return NO;
    }
    
    Il2CppMethod *ctor = _il2cpp_class_get_method_from_name(klass, ".ctor", ctorArgCount);
    if (!ctor) { 
        if (outError) *outError = [NSString stringWithFormat:@"%s .ctor not found", actionClassName]; 
        return NO; 
    }
    
    Il2CppMethod *execute = _il2cpp_class_get_method_from_name(klass, "Execute", 1);
    if (!execute) { 
        if (outError) *outError = [NSString stringWithFormat:@"%s Execute not found", actionClassName]; 
        return NO; 
    }

    Il2CppObject *actionObj = _il2cpp_object_new(klass);
    if (!actionObj) { 
        if (outError) *outError = @"Failed to alloc action"; 
        return NO; 
    }

    Il2CppObject *exc = NULL;
    _il2cpp_runtime_invoke(ctor, actionObj, ctorArgs, &exc);
    if (exc) { 
        if (outError) *outError = [NSString stringWithFormat:@"%s .ctor threw", actionClassName]; 
        return NO; 
    }

    Il2CppObject *appState = getAppState(image);
    if (!appState) {
        if (outError) *outError = @"AppState is null";
        return NO;
    }
    
    void *execArgs[1] = { appState };
    exc = NULL;
    _il2cpp_runtime_invoke(execute, actionObj, execArgs, &exc);
    if (exc) { 
        if (outError) *outError = [NSString stringWithFormat:@"%s Execute threw", actionClassName]; 
        return NO; 
    }
    return YES;
}

#pragma mark - Singleton Resolution

static Il2CppObject *resolveSingleton(Il2CppImage *image, const char *ns, const char *className) {
    if (!image || !_il2cpp_class_from_name) return NULL;
    
    Il2CppClass *klass = _il2cpp_class_from_name(image, ns, className);
    if (!klass) klass = _il2cpp_class_from_name(image, "", className);
    if (!klass) return NULL;

    static const char *getterNames[] = {
        "get_Instance", "GetInstance", "get_Current",
        "get_Singleton", "GetSingleton", "get_instance", NULL
    };
    
    for (int i = 0; getterNames[i]; i++) {
        if (!_il2cpp_class_get_method_from_name) break;
        Il2CppMethod *m = _il2cpp_class_get_method_from_name(klass, getterNames[i], 0);
        if (!m) continue;
        
        Il2CppObject *exc = NULL;
        Il2CppObject *inst = _il2cpp_runtime_invoke(m, NULL, NULL, &exc);
        if (inst && !exc) {
            VYRO_LOG("%s singleton via %s -> %p", className, getterNames[i], inst);
            return inst;
        }
    }

    if (_il2cpp_class_get_field_from_name && _il2cpp_field_static_get_value) {
        static const char *fieldNames[] = {
            "instance", "Instance", "_instance", "s_instance",
            "m_instance", "s_Instance", NULL
        };
        
        for (int i = 0; fieldNames[i]; i++) {
            Il2CppField *f = _il2cpp_class_get_field_from_name(klass, fieldNames[i]);
            if (!f) continue;
            
            Il2CppObject *inst = NULL;
            _il2cpp_field_static_get_value(f, &inst);
            if (inst) {
                VYRO_LOG("%s singleton via field '%s' -> %p", className, fieldNames[i], inst);
                return inst;
            }
        }
    }

    VYRO_LOG("%s: no singleton pattern matched (may be static class)", className);
    return NULL;
}

static Il2CppMethod *probeMethod(Il2CppClass *klass, const char *name, int minArgs, int maxArgs) {
    if (!klass || !_il2cpp_class_get_method_from_name) return NULL;
    
    for (int n = minArgs; n <= maxArgs; n++) {
        Il2CppMethod *m = _il2cpp_class_get_method_from_name(klass, name, n);
        if (m) {
            VYRO_LOG("probeMethod: %s(%d args) -> %p", name, n, m);
            return m;
        }
    }
    VYRO_LOG("probeMethod: %s not found for arg counts %d-%d", name, minArgs, maxArgs);
    return NULL;
}

static Il2CppClass *getPrefabGeneratorClass(void) {
    Il2CppImage *image = getACImage();
    if (!image) return NULL;
    
    static const char *classNames[] = {
        "AnimalCompany.PrefabGenerator",
        "PrefabGenerator",
        "AnimalCompany.ItemSpawner",
        "ItemSpawner",
        NULL
    };
    
    for (int i = 0; classNames[i]; i++) {
        const char *name = classNames[i];
        const char *dot = strchr(name, '.');
        
        Il2CppClass *klass;
        if (dot) {
            char ns[64], cn[64];
            strncpy(ns, name, dot - name);
            ns[dot - name] = '\0';
            strcpy(cn, dot + 1);
            klass = _il2cpp_class_from_name(image, ns, cn);
        } else {
            klass = _il2cpp_class_from_name(image, "", name);
        }
        
        if (klass) return klass;
    }
    
    VYRO_ERROR("PrefabGenerator/ItemSpawner class not found");
    return NULL;
}

static Il2CppObject *getPrefabGeneratorInstance(void) {
    static Il2CppObject *cached = NULL;
    static Il2CppImage *cachedImg = NULL;
    
    Il2CppImage *image = getACImage();
    if (!image) return NULL;
    if (cachedImg == image && cached) return cached;
    
    cachedImg = image;
    cached = resolveSingleton(image, "AnimalCompany", "PrefabGenerator");
    if (!cached) cached = resolveSingleton(image, "", "PrefabGenerator");
    if (!cached) cached = resolveSingleton(image, "AnimalCompany", "ItemSpawner");
    
    return cached;
}

#pragma mark - Spawn Engine

static NSString *doSpawnItem(NSString *itemID, float hue, BOOL networked) {
    if (!_resolved) return @"Il2Cpp not resolved";
    if (!itemID || itemID.length == 0) return @"Invalid item ID";

    Il2CppClass *klass = getPrefabGeneratorClass();
    if (!klass) return @"PrefabGenerator class not found";

    Il2CppObject *inst = getPrefabGeneratorInstance();
    readSpawnPosition();
    
    Vector3 pos = { spawnX, spawnY, spawnZ };
    Quaternion rot = { 0.0f, 0.0f, 0.0f, 1.0f };

    const char *methodName = networked ? "SpawnItemAsync" : "SpawnItem";
    BOOL withHue = (hue >= 0.0f);

    Il2CppMethod *method = NULL;
    if (withHue) {
        method = probeMethod(klass, methodName, 4, 7);
        if (!method && networked) {
            method = probeMethod(klass, "SpawnItem", 4, 7);
            if (method) VYRO_LOG("SpawnItemAsync not found, using SpawnItem");
        }
    }
    
    if (!method) {
        method = probeMethod(klass, methodName, 2, 5);
        if (!method && networked) method = probeMethod(klass, "SpawnItem", 2, 5);
        withHue = NO;
    }
    
    if (!method) {
        return [NSString stringWithFormat:@"%s / SpawnItem — no matching overload", methodName];
    }

    Il2CppString *ms = _il2cpp_string_new(itemID.UTF8String);
    if (!ms) return @"il2cpp_string_new returned NULL";

    void *args[7];
    int argc = 0;
    args[argc++] = ms;
    args[argc++] = &pos;
    args[argc++] = &rot;
    if (withHue) args[argc++] = &hue;
    args[argc++] = NULL;

    Il2CppObject *exc = NULL;
    _il2cpp_runtime_invoke(method, inst, args, &exc);

    if (exc && withHue) {
        VYRO_LOG("SpawnItem w/ hue threw — retrying without hue");
        int argc2 = 0;
        args[argc2++] = ms;
        args[argc2++] = &pos;
        args[argc2++] = &rot;
        args[argc2++] = NULL;
        exc = NULL;
        _il2cpp_runtime_invoke(method, inst, args, &exc);
    }
    
    if (exc) {
        return @"SpawnItem threw an Il2Cpp exception";
    }

    return nil;
}

static void enqueueSpawn(NSString *itemID, float hue, BOOL networked, NSInteger qty) {
    if (!itemID) return;
    
    dispatch_async(spawnQueueLock, ^{
        if (!spawnQueue) spawnQueue = [NSMutableArray array];
        
        PendingSpawn ps = { [itemID copy], hue, networked, qty };
        [spawnQueue addObject:[NSValue valueWithBytes:&ps objCType:@encode(PendingSpawn)]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            setStatus(@"⏳ Queued — retrying…", NO);
        });
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSpawnRetryDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (!_resolved) resolveSymbols();
            if (!_resolved) { 
                setStatus(@"⚠ Il2Cpp still not resolved", NO); 
                return; 
            }
            
            NSArray *q = [spawnQueue copy];
            dispatch_async(spawnQueueLock, ^{
                [spawnQueue removeAllObjects];
            });
            
            for (NSValue *v in q) {
                PendingSpawn ps2; 
                [v getValue:&ps2];
                if (!ps2.itemID) continue;
                
                for (NSInteger i = 0; i < ps2.qty; i++) {
                    NSString *err = doSpawnItem(ps2.itemID, ps2.hue, ps2.networked);
                    if (err) { 
                        setStatus([NSString stringWithFormat:@"⚠ Retry failed: %@", err], NO); 
                        return; 
                    }
                }
                setStatus([NSString stringWithFormat:@"✓ Retry spawned x%ld %@", (long)ps2.qty, ps2.itemID], YES);
            }
        });
    });
}

static void spawnItemWithHue(NSString *itemID, float hue) {
    if (!itemID) return;
    NSString *err = doSpawnItem(itemID, hue, NO);
    if (err) setStatus([NSString stringWithFormat:@"⚠ %@", err], NO);
}

static void spawnItemAsyncWithHue(NSString *itemID, float hue) {
    if (!itemID) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *err = doSpawnItem(itemID, hue, YES);
        if (err) setStatus([NSString stringWithFormat:@"⚠ Async: %@", err], NO);
    });
}

#pragma mark - Mob Spawning

static void spawnMobNearbyPlayer(NSString *mobIDStr, float radius) {
    if (!_resolved) { setStatus(@"⚠ Il2Cpp not resolved", NO); return; }
    if (!mobIDStr || mobIDStr.length == 0) { setStatus(@"⚠ Invalid mob ID", NO); return; }

    Il2CppClass *klass = getPrefabGeneratorClass();
    if (!klass) { setStatus(@"⚠ PrefabGenerator not found", NO); return; }

    Il2CppObject *inst = getPrefabGeneratorInstance();
    readSpawnPosition();

    int mobIDVal = (int)[mobIDStr integerValue];
    Il2CppString *spawnSrc = _il2cpp_string_new("VyroClient");
    Il2CppObject *exc = NULL;

    // Strategy 1 — SpawnMobNearbyPlayerAsync
    Il2CppMethod *method = probeMethod(klass, "SpawnMobNearbyPlayerAsync", 2, 6);
    if (method) {
        void *args[6] = { &mobIDVal, &radius, NULL, NULL, spawnSrc, NULL };
        _il2cpp_runtime_invoke(method, inst, args, &exc);
        if (!exc) {
            setStatus([NSString stringWithFormat:@"✓ Spawned mob %@ (r=%.0f)", mobIDStr, radius], YES);
            return;
        }
        VYRO_LOG("SpawnMobNearbyPlayerAsync threw — trying fallback");
        exc = NULL;
    }

    // Strategy 2 — SpawnMobAsync / SpawnMob
    method = probeMethod(klass, "SpawnMobAsync", 3, 7);
    if (!method) method = probeMethod(klass, "SpawnMob", 3, 7);
    
    if (method) {
        Vector3 pos = { spawnX, spawnY, spawnZ };
        Quaternion rot = { 0.0f, 0.0f, 0.0f, 1.0f };
        void *args[7] = { &mobIDVal, &pos, &rot, NULL, NULL, spawnSrc, NULL };
        _il2cpp_runtime_invoke(method, inst, args, &exc);
        if (!exc) {
            setStatus([NSString stringWithFormat:@"✓ Spawned mob %@ at (%.1f,%.1f,%.1f)",
                       mobIDStr, spawnX, spawnY, spawnZ], YES);
            return;
        }
        VYRO_ERROR("SpawnMobAsync also threw");
    }

    setStatus(@"⚠ SpawnMob: no working method found", NO);
}

#pragma mark - Scenery Patches

static uintptr_t getGameSlide(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, "AnimalCompany") && !strstr(name, "UnityFramework"))
            return (uintptr_t)_dyld_get_image_vmaddr_slide(i);
    }
    return (uintptr_t)_dyld_get_image_vmaddr_slide(0);
}

static BOOL patchBoolGetter(uintptr_t rva, BOOL returnValue) {
    uintptr_t slide = getGameSlide();
    uintptr_t addr = slide + rva;
    uintptr_t page = addr & ~(uintptr_t)(getpagesize() - 1);
    
    if (mprotect((void *)page, getpagesize() * 2, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
        VYRO_ERROR("mprotect failed for RVA 0x%lx errno=%d", rva, errno);
        return NO;
    }
    
    uint32_t *code = (uint32_t *)addr;
    code[0] = 0x52800000 | ((returnValue ? 1 : 0) << 5);
    code[1] = 0xD65F03C0;
    sys_icache_invalidate((void *)addr, 8);
    mprotect((void *)page, getpagesize() * 2, PROT_READ | PROT_EXEC);
    
    VYRO_LOG("Patched getter at 0x%lx -> return %d", addr, returnValue);
    return YES;
}

static void setSceneryHalloween(BOOL enabled) {
    if (patchBoolGetter(RVA_isHalloween, enabled)) {
        sceneryHalloween = enabled;
        setStatus(enabled ? @"🎃 Halloween ON" : @"🎃 Halloween OFF", YES);
    } else { 
        setStatus(@"⚠ Halloween patch failed", NO); 
    }
}

static void setSceneryThanksgiving(BOOL enabled) {
    if (patchBoolGetter(RVA_isThanksgiving, enabled)) {
        sceneryThanksgiving = enabled;
        setStatus(enabled ? @"🦃 Thanksgiving ON" : @"🦃 Thanksgiving OFF", YES);
    } else { 
        setStatus(@"⚠ Thanksgiving patch failed", NO); 
    }
}

static void setScenerySnowStorm(BOOL enabled) {
    if (patchBoolGetter(RVA_isSnowStorm, enabled)) {
        scenerySnowStorm = enabled;
        setStatus(enabled ? @"❄️ Snow Storm ON" : @"❄️ Snow Storm OFF", YES);
    } else { 
        setStatus(@"⚠ SnowStorm patch failed", NO); 
    }
}

static void setSceneryHeavyRain(BOOL enabled) {
    if (patchBoolGetter(RVA_isHeavyRain, enabled)) {
        sceneryHeavyRain = enabled;
        setStatus(enabled ? @"🌧️ Heavy Rain ON" : @"🌧️ Heavy Rain OFF", YES);
    } else { 
        setStatus(@"⚠ HeavyRain patch failed", NO); 
    }
}

#pragma mark - Camera Tracking

static Vector3 getCameraPosition(void) {
    Vector3 zero = {0, 0, 0};
    if (!_resolved) return zero;
    
    Il2CppDomain *domain = _il2cpp_domain_get();
    if (!domain) return zero;
    
    Il2CppAssembly *coreAssembly = _il2cpp_domain_assembly_open(domain, "UnityEngine.CoreModule");
    if (!coreAssembly) coreAssembly = _il2cpp_domain_assembly_open(domain, "UnityEngine");
    if (!coreAssembly) return zero;
    
    Il2CppImage *coreImage = _il2cpp_assembly_get_image(coreAssembly);
    if (!coreImage) return zero;
    
    Il2CppClass *camClass = _il2cpp_class_from_name(coreImage, "UnityEngine", "Camera");
    if (!camClass) return zero;
    
    Il2CppMethod *getMain = _il2cpp_class_get_method_from_name(camClass, "get_main", 0);
    if (!getMain) return zero;
    
    Il2CppObject *exc = NULL;
    Il2CppObject *mainCam = _il2cpp_runtime_invoke(getMain, NULL, NULL, &exc);
    if (!mainCam || exc) return zero;
    
    Il2CppClass *componentClass = _il2cpp_class_from_name(coreImage, "UnityEngine", "Component");
    if (!componentClass) return zero;
    
    Il2CppMethod *getTransform = _il2cpp_class_get_method_from_name(componentClass, "get_transform", 0);
    if (!getTransform) return zero;
    
    exc = NULL;
    Il2CppObject *transform = _il2cpp_runtime_invoke(getTransform, mainCam, NULL, &exc);
    if (!transform || exc) return zero;
    
    Il2CppClass *transformClass = _il2cpp_class_from_name(coreImage, "UnityEngine", "Transform");
    if (!transformClass) return zero;
    
    Il2CppMethod *getPos = _il2cpp_class_get_method_from_name(transformClass, "get_position", 0);
    if (!getPos) return zero;
    
    exc = NULL;
    Il2CppObject *boxedPos = _il2cpp_runtime_invoke(getPos, transform, NULL, &exc);
    if (!boxedPos || exc) return zero;
    
    void *rawPtr = _il2cpp_object_unbox ? _il2cpp_object_unbox(boxedPos) : NULL;
    if (rawPtr) {
        Vector3 r;
        memcpy(&r, rawPtr, sizeof(Vector3));
        return r;
    }
    
    Vector3 r;
    memcpy(&r, (uint8_t *)boxedPos + 0x10, sizeof(Vector3));
    return r;
}

static void pollCameraPosition(void) {
    Vector3 pos = getCameraPosition();
    NSString *line = [NSString stringWithFormat:@"X: %8.3f  Y: %8.3f  Z: %8.3f", pos.x, pos.y, pos.z];
    VYRO_LOG("Camera %{public}@", line);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (camPosLabel) camPosLabel.text = line;
        
        if (!camLog) camLog = [NSMutableArray array];
        
        NSString *ts = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                      dateStyle:NSDateFormatterNoStyle
                                                      timeStyle:NSDateFormatterMediumStyle];
        [camLog insertObject:[NSString stringWithFormat:@"%@  %@", ts, line] atIndex:0];
        
        if (camLog.count > kMaxCameraLogEntries) [camLog removeLastObject];
        if (camLogLabel) camLogLabel.text = [camLog componentsJoinedByString:@"\n"];
    });
}

static void startCameraTracking(void) {
    if (camTimer) return;
    if (!camLog) camLog = [NSMutableArray array];
    
    camTimer = [NSTimer scheduledTimerWithTimeInterval:kCameraPollInterval
                                               target:[NSBlockOperation blockOperationWithBlock:^{ 
                                                   pollCameraPosition(); 
                                               }]
                                             selector:@selector(main)
                                             userInfo:nil
                                              repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:camTimer forMode:NSRunLoopCommonModes];
}

static void stopCameraTracking(void) {
    [camTimer invalidate];
    camTimer = nil;
}

#pragma mark - Fart Power

static void setFarty(BOOL enabled) {
    NSString *err = nil;
    int val = enabled ? 1 : 0;
    void *ctorArgs[1] = { &val };
    
    BOOL ok = invokeAction("SetPlayerIsFartyAction", ctorArgs, 1, &err);
    
    if (ok) {
        setStatus(enabled ? @"💨 Fart Power ENABLED" : @"💨 Fart Power disabled", YES);
    } else {
        setStatus([NSString stringWithFormat:@"⚠ %@", err ?: @"Fart Power failed"], NO);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            fartyEnabled = !enabled;
            if (fartyBtn) {
                [fartyBtn setTitle:fartyEnabled ? @"💨  Fart Power: ON" : @"💨  Enable Fart Power"
                          forState:UIControlStateNormal];
                fartyBtn.backgroundColor = fartyEnabled
                    ? [UIColor colorWithRed:0.20 green:0.45 blue:0.10 alpha:1]
                    : [UIColor colorWithRed:0.30 green:0.20 blue:0.05 alpha:1];
            }
        });
    }
}

#pragma mark - Yeet Spam

static void stopYeetSpamTimer(void) {
    if (yeetSpamTimer) {
        [yeetSpamTimer invalidate];
        yeetSpamTimer = nil;
    }
    yeetSpamEnabled = NO;
}

static void startYeetSpam(BOOL enabled) {
    if (enabled) {
        yeetSpamEnabled = YES;
        yeetSpamTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *t) {
            if (!yeetSpamEnabled) {
                [t invalidate];
                return;
            }
            NSString *err = nil;
            int val = 1;
            void *ctorArgs[1] = { &val };
            invokeAction("SetPlayerIsYeetingAction", ctorArgs, 1, &err);
        }];
        [[NSRunLoop currentRunLoop] addTimer:yeetSpamTimer forMode:NSDefaultRunLoopMode];
        setStatus(@"⚡ Yeet Spam STARTED", YES);
    } else {
        stopYeetSpamTimer();
        setStatus(@"⚡ Yeet Spam STOPPED", YES);
    }
}

#pragma mark - Kill Spam

static void stopKillSpamTimer(void) {
    if (killSpamTimer) {
        [killSpamTimer invalidate];
        killSpamTimer = nil;
    }
    killSpamEnabled = NO;
}

static void startKillSpam(BOOL enabled) {
    if (enabled) {
        killSpamEnabled = YES;
        killSpamTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *t) {
            if (!killSpamEnabled) {
                [t invalidate];
                return;
            }
            NSString *err = nil;
            int val = 1;
            void *ctorArgs[1] = { &val };
            invokeAction("SetPlayerIsDeadAction", ctorArgs, 1, &err);
        }];
        [[NSRunLoop currentRunLoop] addTimer:killSpamTimer forMode:NSDefaultRunLoopMode];
        setStatus(@"💀 Kill Spam STARTED", YES);
    } else {
        stopKillSpamTimer();
        setStatus(@"💀 Kill Spam STOPPED", YES);
    }
}

#pragma mark - JSON Parsing

typedef struct {
    NSString *itemID;
    float hue;
    NSArray *children;
} JSONItem;

static NSArray *parseJSON(NSData *data) {
    if (!data) return nil;
    
    NSError *error = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        VYRO_ERROR("JSON parse error: %{public}@", error);
        return nil;
    }
    if (!obj) return nil;
    
    NSMutableArray *out = [NSMutableArray array];
    
    void(^processItem)(id) = ^(id item) {
        JSONItem ji;
        ji.itemID = nil;
        ji.hue = -1.0f;
        ji.children = nil;
        
        if ([item isKindOfClass:[NSString class]]) {
            ji.itemID = (NSString *)item;
        } else if ([item isKindOfClass:[NSDictionary class]]) {
            NSDictionary *d = item;
            ji.itemID = d[@"id"] ?: d[@"itemID"] ?: d[@"item_id"] ?: d[@"name"];
            
            id hv = d[@"hue"];
            if ([hv isKindOfClass:[NSNumber class]]) ji.hue = [(NSNumber *)hv floatValue];
            
            id cd = d[@"children"] ?: d[@"child_items"] ?: d[@"items"];
            if ([cd isKindOfClass:[NSArray class]]) {
                NSMutableArray *cids = [NSMutableArray array];
                for (id c in (NSArray *)cd) {
                    if ([c isKindOfClass:[NSString class]]) {
                        [cids addObject:c];
                    } else if ([c isKindOfClass:[NSDictionary class]]) {
                        NSString *cid = ((NSDictionary *)c)[@"id"] ?: ((NSDictionary *)c)[@"itemID"] ?: ((NSDictionary *)c)[@"item_id"];
                        if (cid) [cids addObject:cid];
                    }
                }
                if (cids.count) ji.children = [cids copy];
            }
        }
        
        if (ji.itemID) {
            [out addObject:[NSValue valueWithBytes:&ji objCType:@encode(JSONItem)]];
        }
    };
    
    if ([obj isKindOfClass:[NSArray class]]) {
        for (id i in (NSArray *)obj) processItem(i);
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        NSArray *arr = ((NSDictionary *)obj)[@"items"] ?: ((NSDictionary *)obj)[@"ids"];
        if ([arr isKindOfClass:[NSArray class]]) {
            for (id i in arr) processItem(i);
        }
    }
    
    return out.count ? [out copy] : nil;
}

#pragma mark - Bitmap Font Functions

static const Glyph5x7 *glyphForChar(unichar c) {
    if (c == ' ') return &kFont5x7[0];
    if (c >= 'a' && c <= 'z') c = c - 'a' + 'A';
    if (c >= 32 && c <= 90) return &kFont5x7[c - 32];
    return &kFont5x7[0];
}

static NSInteger pixelCountForString(NSString *text) {
    if (!text) return 0;
    NSInteger total = 0;
    
    for (NSUInteger i = 0; i < text.length; i++) {
        const Glyph5x7 *g = glyphForChar([text characterAtIndex:i]);
        for (int col = 0; col < 5; col++) {
            uint8_t colBits = g->col[col];
            for (int row = 0; row < 7; row++) {
                if (colBits & (1 << (6 - row))) total++;
            }
        }
    }
    return total;
}

static NSString *asciiPreviewForString(NSString *text) {
    if (!text) return @"(empty)";
    
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:7];
    for (int r = 0; r < 7; r++) [rows addObject:[NSMutableString string]];
    
    for (NSUInteger ci = 0; ci < text.length; ci++) {
        const Glyph5x7 *g = glyphForChar([text characterAtIndex:ci]);
        for (int col = 0; col < 5; col++) {
            for (int row = 0; row < 7; row++) {
                BOOL lit = (g->col[col] & (1 << (6 - row))) != 0;
                [rows[row] appendString:lit ? @"█" : @"·"];
            }
        }
        for (int row = 0; row < 7; row++) [rows[row] appendString:@" "];
    }
    
    return [rows componentsJoinedByString:@"\n"];
}

#pragma mark - Writer Spawn Engine

static void spawnTextInWorld(NSString *text, NSString *itemID,
                              float originX, float originY, float originZ,
                              float scale, float letterSpacing, int axis) {
    if (!_resolved) { setStatus(@"⚠ Il2Cpp not resolved", NO); return; }
    if (!text.length || !itemID.length) { setStatus(@"⚠ Enter text and item ID", NO); return; }

    NSString *upperText = [text uppercaseString];
    NSInteger total = pixelCountForString(upperText);
    setStatus([NSString stringWithFormat:@"⏳ Spawning %ld items…", (long)total], NO);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        float cursorU = 0.0f;
        NSInteger spawned = 0;
        NSInteger failed = 0;

        for (NSUInteger ci = 0; ci < upperText.length; ci++) {
            const Glyph5x7 *g = glyphForChar([upperText characterAtIndex:ci]);

            for (int col = 0; col < 5; col++) {
                for (int row = 0; row < 7; row++) {
                    if (!(g->col[col] & (1 << (6 - row)))) continue;

                    float u = cursorU + col * scale;
                    float v = (6 - row) * scale;
                    float wx, wy, wz;

                    wy = originY + v;
                    if (axis == 0) { wx = originX + u; wz = originZ; }
                    else           { wz = originZ + u; wx = originX; }

                    spawnX = wx; spawnY = wy; spawnZ = wz;

                    NSString *err = doSpawnItem(itemID, -1.0f, NO);
                    if (err) failed++; else spawned++;

                    [NSThread sleepForTimeInterval:kSpawnThreadSleep];
                }
            }
            cursorU += (5 + letterSpacing) * scale;
        }

        spawnX = originX; spawnY = originY; spawnZ = originZ;

        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *msg;
            if (failed == 0)
                msg = [NSString stringWithFormat:@"Wrote \"%@\" - %ld items spawned", upperText, (long)spawned];
            else
                msg = [NSString stringWithFormat:@"Wrote \"%@\" - %ld ok, %ld failed", upperText, (long)spawned, (long)failed];
            setStatus(msg, failed == 0);
            if (writerStatusLabel) writerStatusLabel.text = msg;
        });
    });
}

static void spawnGridPattern(NSString *itemID,
                              float originX, float originY, float originZ,
                              float scale, int axis) {
    if (!_resolved) { setStatus(@"⚠ Il2Cpp not resolved", NO); return; }
    if (!itemID.length) { setStatus(@"⚠ Enter item ID", NO); return; }

    NSInteger total = 0;
    for (int r = 0; r < GRID_ROWS; r++)
        for (int c = 0; c < GRID_COLS; c++)
            if (gridCells[r][c]) total++;

    if (total == 0) { setStatus(@"⚠ Paint some cells first", NO); return; }
    
    setStatus([NSString stringWithFormat:@"⏳ Spawning %ld grid items…", (long)total], NO);

    // Snapshot grid state
    NSMutableArray *snapshotArr = [NSMutableArray arrayWithCapacity:GRID_ROWS * GRID_COLS];
    for (int r = 0; r < GRID_ROWS; r++)
        for (int c = 0; c < GRID_COLS; c++)
            [snapshotArr addObject:@(gridCells[r][c])];
    
    NSString *itemCopy = [itemID copy];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSInteger spawned = 0, failed = 0;
        
        for (int row = 0; row < GRID_ROWS; row++) {
            for (int col = 0; col < GRID_COLS; col++) {
                if (![snapshotArr[row * GRID_COLS + col] boolValue]) continue;
                
                float u = col * scale;
                float v = (GRID_ROWS - 1 - row) * scale;
                float wx, wy, wz;
                
                wy = originY + v;
                if (axis == 0) { wx = originX + u; wz = originZ; }
                else           { wz = originZ + u; wx = originX; }
                
                spawnX = wx; spawnY = wy; spawnZ = wz;
                
                NSString *err = doSpawnItem(itemCopy, -1.0f, NO);
                if (err) failed++; else spawned++;
                
                [NSThread sleepForTimeInterval:kSpawnThreadSleep];
            }
        }
        
        spawnX = originX; spawnY = originY; spawnZ = originZ;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *msg = failed == 0
                ? [NSString stringWithFormat:@"✓ Grid spawned — %ld items", (long)spawned]
                : [NSString stringWithFormat:@"⚠ Grid — %ld ok, %ld failed", (long)spawned, (long)failed];
            setStatus(msg, failed == 0);
        });
    });
}

static void updateWriterPreview(void) {
    if (!writerTextField || !writerPreviewLabel) return;
    
    NSString *t = [writerTextField.text uppercaseString];
    if (!t.length) { 
        writerPreviewLabel.text = @"(type text above)"; 
        return; 
    }
    
    NSString *preview = t.length > 6 ? [t substringToIndex:6] : t;
    writerPreviewLabel.text = asciiPreviewForString(preview);
}

#pragma mark - UI Classes

@interface ACPassthroughWindow : UIWindow @end
@implementation ACPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self.rootViewController.view) return nil;
    return hit;
}
@end

@interface ACDragButton : UIButton
@property (nonatomic, assign) BOOL didDrag;
@end
@implementation ACDragButton
- (void)tapped { if (!self.didDrag) toggleMenu(); }
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint d = [pan translationInView:self.superview];
    CGRect f = self.frame, s = UIScreen.mainScreen.bounds;
    f.origin.x = MAX(0,  MIN(f.origin.x+d.x, s.size.width -f.size.width));
    f.origin.y = MAX(20, MIN(f.origin.y+d.y, s.size.height-f.size.height));
    self.frame = f; [pan setTranslation:CGPointZero inView:self.superview];
    self.didDrag = YES;
    if (pan.state == UIGestureRecognizerStateEnded) self.didDrag = NO;
}
@end

@interface ACPanView : UIView @end
@implementation ACPanView
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint d = [pan translationInView:self.superview];
    CGRect f = self.frame, s = UIScreen.mainScreen.bounds;
    f.origin.x = MAX(0,  MIN(f.origin.x+d.x, s.size.width -f.size.width));
    f.origin.y = MAX(20, MIN(f.origin.y+d.y, s.size.height-f.size.height));
    self.frame = f; [pan setTranslation:CGPointZero inView:self.superview];
}
@end

@interface ACBtn : UIButton
@property (nonatomic, copy) void(^action)(UIButton *);
@end
@implementation ACBtn
- (void)tapped { if (self.action) self.action(self); }
@end

@interface ACPickerDS : NSObject <UIPickerViewDataSource, UIPickerViewDelegate> @end
@implementation ACPickerDS
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pv { return 1; }
- (NSInteger)pickerView:(UIPickerView *)pv numberOfRowsInComponent:(NSInteger)c { 
    return (NSInteger)jsonIDs.count; 
}
- (UIView *)pickerView:(UIPickerView *)pv viewForRow:(NSInteger)r forComponent:(NSInteger)c reusingView:(UIView *)view {
    UILabel *l = [view isKindOfClass:[UILabel class]] ? (UILabel *)view : [[UILabel alloc] init];
    if (r < 0 || r >= (NSInteger)jsonIDs.count) return l;
    
    NSValue *val = jsonIDs[(NSUInteger)r]; 
    JSONItem item; 
    [val getValue:&item];
    
    NSString *dt = item.itemID;
    if (item.hue >= 0.0f) dt = [NSString stringWithFormat:@"%@ (hue: %.1f)", item.itemID, item.hue];
    if (item.children.count) dt = [NSString stringWithFormat:@"%@ [+%lu child]", dt, (unsigned long)item.children.count];
    
    l.text = dt; 
    l.textColor = [UIColor colorWithRed:1.0 green:0.75 blue:0.75 alpha:1];
    l.font = [UIFont fontWithName:@"Menlo" size:12]; 
    l.textAlignment = NSTextAlignmentCenter;
    return l;
}
- (void)pickerView:(UIPickerView *)pv didSelectRow:(NSInteger)r inComponent:(NSInteger)c {
    if (r < 0 || r >= (NSInteger)jsonIDs.count) return;
    if (jsonIDs.count) { 
        NSValue *val = jsonIDs[(NSUInteger)r]; 
        JSONItem item; 
        [val getValue:&item]; 
        if (idField) idField.text = item.itemID; 
    }
}
@end
static ACPickerDS *_pickerDS;

@interface ACDocDelegate : NSObject <UIDocumentPickerDelegate> @end
@implementation ACDocDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)c didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    NSURL *url = urls.firstObject; 
    if (!url) return;
    
    BOOL access = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (access) [url stopAccessingSecurityScopedResource];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *items = data ? parseJSON(data) : nil;
        if (!items) { 
            setStatus(@"⚠ No items found in JSON.", NO); 
            return; 
        }
        
        if (!jsonIDs) jsonIDs = [NSMutableArray array];
        [jsonIDs removeAllObjects]; 
        [jsonIDs addObjectsFromArray:items];
        
        if (idPicker) {
            [idPicker reloadAllComponents]; 
            [idPicker selectRow:0 inComponent:0 animated:NO];
        }
        
        if (jsonIDs.count) { 
            NSValue *val = jsonIDs[0]; 
            JSONItem item; 
            [val getValue:&item]; 
            if (idField) idField.text = item.itemID; 
        }
        
        if (pickerCard) pickerCard.hidden = NO;
        setStatus([NSString stringWithFormat:@"✓ Loaded %lu items from JSON", (unsigned long)items.count], YES);
    });
}
@end
static ACDocDelegate *_docDelegate;

#pragma mark - UI Helpers

static void openJSONPicker(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!_docDelegate) _docDelegate = [ACDocDelegate new];
        
        UIDocumentPickerViewController *picker;
        if (@available(iOS 14.0, *)) {
            NSArray *types = @[
                [UTType typeWithIdentifier:@"public.json"],
                [UTType typeWithIdentifier:@"public.text"],
                [UTType typeWithIdentifier:@"public.data"]
            ];
            picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            picker = [[UIDocumentPickerViewController alloc]
                initWithDocumentTypes:@[@"public.json", @"public.text", @"public.data"]
                               inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
        }
        
        picker.delegate = _docDelegate;
        picker.allowsMultipleSelection = NO;
        
        UIViewController *root = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
                if ([sc isKindOfClass:[UIWindowScene class]] &&
                    sc.activationState == UISceneActivationStateForegroundActive) {
                    root = ((UIWindowScene*)sc).windows.firstObject.rootViewController; 
                    break;
                }
            }
        }
        if (!root) root = UIApplication.sharedApplication.delegate.window.rootViewController;
        if (root) [root presentViewController:picker animated:YES completion:nil];
    });
}

static ACBtn *makeBtn(NSString *title, UIColor *col, CGRect f, void(^act)(UIButton *)) {
    ACBtn *b = [ACBtn buttonWithType:UIButtonTypeSystem];
    b.frame = f; 
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:col forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    b.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    b.layer.borderWidth = 1.2; 
    b.layer.borderColor = [col colorWithAlphaComponent:0.40].CGColor;
    b.action = act; 
    [b addTarget:b action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static UILabel *secLabel(NSString *t, CGRect f) {
    UILabel *l = [[UILabel alloc] initWithFrame:f];
    l.text = t; 
    l.font = [UIFont boldSystemFontOfSize:10];
    l.textColor = [UIColor colorWithWhite:0.50 alpha:1]; 
    return l;
}

static UIToolbar *createKeyboardToolbar(void) {
    UIToolbar *kb = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    kb.barStyle = UIBarStyleBlack; 
    kb.translucent = YES;
    
    UIBarButtonItem *flexSp = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    ACBtn *doneBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    doneBtn.frame = CGRectMake(0, 0, 60, 36);
    [doneBtn setTitle:@"✓ Done" forState:UIControlStateNormal];
    [doneBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.65 blue:0.65 alpha:1] forState:UIControlStateNormal];
    doneBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    doneBtn.action = ^(UIButton *b){
        for (UITextField *f in @[idField, xField, yField, zField, mobIDField, mobRadiusField])
            if ([f isFirstResponder]) { [f resignFirstResponder]; break; }
    };
    [doneBtn addTarget:doneBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    
    kb.items = @[flexSp, [[UIBarButtonItem alloc] initWithCustomView:doneBtn]];
    return kb;
}

static UITextField *styledField(CGRect frame, NSString *placeholder) {
    UITextField *f = [[UITextField alloc] initWithFrame:frame];
    f.backgroundColor = [UIColor colorWithRed:0.16 green:0.04 blue:0.04 alpha:1];
    f.textColor = UIColor.whiteColor; 
    f.font = [UIFont fontWithName:@"Menlo" size:14];
    f.borderStyle = UITextBorderStyleNone; 
    f.layer.borderWidth = 1.3;
    f.layer.borderColor = [UIColor colorWithRed:0.80 green:0.15 blue:0.15 alpha:0.65].CGColor;
    f.returnKeyType = UIReturnKeyDone; 
    f.autocorrectionType = UITextAutocorrectionTypeNo;
    f.autocapitalizationType = UITextAutocapitalizationTypeNone;
    f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, frame.size.height)];
    f.leftViewMode = UITextFieldViewModeAlways;
    f.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder ?: @""
        attributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:0.36 alpha:1]}];
    f.inputAccessoryView = createKeyboardToolbar();
    return f;
}

static UITextField *numericField(CGRect frame, NSString *placeholder) {
    UITextField *f = styledField(frame, placeholder);
    f.keyboardType = UIKeyboardTypeDecimalPad; 
    return f;
}

static UIColor *tabActiveColor(void)   { 
    return [UIColor colorWithRed:0.75 green:0.10 blue:0.10 alpha:1]; 
}

static UIColor *tabInactiveColor(void) { 
    return [UIColor colorWithRed:0.35 green:0.06 blue:0.06 alpha:1]; 
}

static void switchToTab(NSInteger tab) {
    _currentTabIndex = tab; // Track for display mode rebuild
    if (itemsTabView) itemsTabView.hidden    = (tab != 0);
    if (mobTabView) mobTabView.hidden      = (tab != 1);
    if (cameraTabView) cameraTabView.hidden   = (tab != 2);
    if (sceneryTabView) sceneryTabView.hidden  = (tab != 3);
    if (settingsTabView) settingsTabView.hidden = (tab != 4);
    if (writerTabView) writerTabView.hidden   = (tab != 5);
    
    if (itemsTabBtn) itemsTabBtn.backgroundColor    = (tab == 0) ? tabActiveColor() : tabInactiveColor();
    if (mobTabBtn) mobTabBtn.backgroundColor      = (tab == 1) ? tabActiveColor() : tabInactiveColor();
    if (cameraTabBtn) cameraTabBtn.backgroundColor   = (tab == 2) ? tabActiveColor() : tabInactiveColor();
    if (sceneryTabBtn) sceneryTabBtn.backgroundColor  = (tab == 3) ? tabActiveColor() : tabInactiveColor();
    if (settingsTabBtn) settingsTabBtn.backgroundColor = (tab == 4) ? tabActiveColor() : tabInactiveColor();
    if (writerTabBtn) writerTabBtn.backgroundColor   = (tab == 5) ? tabActiveColor() : tabInactiveColor();
    
    for (UIButton *b in @[itemsTabBtn, mobTabBtn, cameraTabBtn, sceneryTabBtn, settingsTabBtn, writerTabBtn])
        if (b) [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
}

#pragma mark - Tab Builders

static UIScrollView *buildWriterTab(CGFloat w, CGFloat h) {
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    sv.backgroundColor = UIColor.clearColor;
    sv.alwaysBounceVertical = YES; 
    sv.showsVerticalScrollIndicator = YES;
    sv.delaysContentTouches = NO;

    CGFloat pad = 14, gap = 10, fieldH = 42, labelH = 16;
    CGFloat gridCellSz = (w - pad*2 - (GRID_COLS-1)*3) / (CGFloat)GRID_COLS;
    CGFloat gridH = gridCellSz * GRID_ROWS + (GRID_ROWS-1)*3;
    CGFloat totalH = gap + 22+gap + labelH+4+fieldH+gap + labelH+4+fieldH+gap + 84+gap + labelH+4 + (labelH+4+fieldH+gap)*4 + 52+gap + 22+gap + gridH+gap + labelH+4+fieldH+gap + labelH+4+fieldH+gap + 44+gap + 44+gap + 24;

    UIView *content = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, totalH)];
    [sv addSubview:content]; 
    sv.contentSize = CGSizeMake(w, totalH);

    CGFloat cy = gap;

    // Header
    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 22)];
    hdr.text = @"✍️  ITEM WRITER";
    hdr.textColor = [UIColor colorWithRed:0.85 green:0.55 blue:1.0 alpha:1];
    hdr.font = [UIFont boldSystemFontOfSize:14];
    [content addSubview:hdr]; cy += 22+gap;

    // Text field
    UILabel *textLbl = secLabel(@"TEXT TO WRITE IN THE AIR", CGRectMake(pad, cy, w-pad*2, labelH));
    [content addSubview:textLbl]; cy += labelH+4;

    writerTextField = styledField(CGRectMake(pad, cy, w-pad*2, fieldH), @"e.g.  VYRO");
    writerTextField.layer.borderColor = [UIColor colorWithRed:0.70 green:0.30 blue:1.0 alpha:0.7].CGColor;
    [[NSNotificationCenter defaultCenter] addObserverForName:UITextFieldTextDidChangeNotification
        object:writerTextField queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){
        updateWriterPreview();
    }];
    [content addSubview:writerTextField]; cy += fieldH+gap;

    // Item ID
    [content addSubview:secLabel(@"ITEM ID  (what to spawn at each pixel)", CGRectMake(pad, cy, w-pad*2, labelH))];
    cy += labelH+4;
    writerItemIDField = styledField(CGRectMake(pad, cy, w-pad*2, fieldH), @"e.g.  item_rock");
    writerItemIDField.layer.borderColor = [UIColor colorWithRed:0.70 green:0.30 blue:1.0 alpha:0.7].CGColor;
    [content addSubview:writerItemIDField]; cy += fieldH+gap;

    // ASCII preview
    UIView *prevBox = [[UIView alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 84)];
    prevBox.backgroundColor = [UIColor colorWithRed:0.06 green:0.02 blue:0.10 alpha:1];
    prevBox.layer.borderWidth = 1.2;
    prevBox.layer.borderColor = [UIColor colorWithRed:0.60 green:0.20 blue:0.90 alpha:0.45].CGColor;
    prevBox.layer.cornerRadius = 6;
    [content addSubview:prevBox];

    writerPreviewLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, w-pad*2-16, 76)];
    writerPreviewLabel.text = @"(type text above)";
    writerPreviewLabel.textColor = [UIColor colorWithRed:0.75 green:0.45 blue:1.0 alpha:1];
    writerPreviewLabel.font = [UIFont fontWithName:@"Menlo" size:8];
    writerPreviewLabel.numberOfLines = 0;
    writerPreviewLabel.adjustsFontSizeToFitWidth = YES;
    [prevBox addSubview:writerPreviewLabel];
    cy += 84+gap;

    // Parameters
    [content addSubview:secLabel(@"PARAMETERS", CGRectMake(pad, cy, w-pad*2, labelH))]; cy += labelH+4;

    CGFloat halfW = (w - pad*2 - 8) / 2.0;

    // Scale + Letter spacing
    UILabel *scaleLbl = secLabel(@"SCALE (units/pixel)", CGRectMake(pad, cy, halfW, labelH));
    [content addSubview:scaleLbl];
    UILabel *spaceLbl = secLabel(@"LETTER SPACING", CGRectMake(pad+halfW+8, cy, halfW, labelH));
    [content addSubview:spaceLbl];
    cy += labelH+4;

    writerScaleField = numericField(CGRectMake(pad, cy, halfW, fieldH), @"1.0");
    writerScaleField.text = @"1.0";
    writerScaleField.layer.borderColor = [UIColor colorWithRed:0.70 green:0.30 blue:1.0 alpha:0.5].CGColor;
    [content addSubview:writerScaleField];

    writerSpacingField = numericField(CGRectMake(pad+halfW+8, cy, halfW, fieldH), @"1  (pixels)");
    writerSpacingField.text = @"1";
    writerSpacingField.layer.borderColor = [UIColor colorWithRed:0.70 green:0.30 blue:1.0 alpha:0.5].CGColor;
    [content addSubview:writerSpacingField];
    cy += fieldH+gap;

    // Axis selector
    [content addSubview:secLabel(@"WRITE AXIS  (X = east/west, Z = north/south)", CGRectMake(pad, cy, w-pad*2, labelH))];
    cy += labelH+4;
    writerAxisField = styledField(CGRectMake(pad, cy, halfW, fieldH), @"X or Z");
    writerAxisField.text = @"X";
    writerAxisField.layer.borderColor = [UIColor colorWithRed:0.70 green:0.30 blue:1.0 alpha:0.5].CGColor;
    [content addSubview:writerAxisField];
    cy += fieldH+gap;

    // Info card
    UIView *infoCard = [[UIView alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 52)];
    infoCard.backgroundColor = [UIColor colorWithRed:0.08 green:0.04 blue:0.12 alpha:1];
    infoCard.layer.borderWidth = 1;
    infoCard.layer.borderColor = [UIColor colorWithRed:0.60 green:0.20 blue:0.90 alpha:0.30].CGColor;
    infoCard.layer.cornerRadius = 6;
    [content addSubview:infoCard];
    UILabel *infoTxt = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, w-pad*2-20, 42)];
    infoTxt.text = @"Origin uses your Spawn Position from Settings.\nItems spawn in a 5×7 pixel bitmap font grid.\nSupports A–Z, 0–9 and basic symbols.";
    infoTxt.textColor = [UIColor colorWithWhite:0.48 alpha:1];
    infoTxt.font = [UIFont systemFontOfSize:10]; infoTxt.numberOfLines = 0;
    [infoCard addSubview:infoTxt]; cy += 52+gap;

    // WRITE button
    ACBtn *writeBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    writeBtn.frame = CGRectMake(pad, cy, w-pad*2, 52);
    [writeBtn setTitle:@"✍️  WRITE IN THE AIR" forState:UIControlStateNormal];
    [writeBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    writeBtn.backgroundColor = [UIColor colorWithRed:0.38 green:0.10 blue:0.55 alpha:1];
    writeBtn.layer.borderWidth = 1.8;
    writeBtn.layer.borderColor = [UIColor colorWithRed:0.75 green:0.35 blue:1.0 alpha:1].CGColor;
    writeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    writeBtn.action = ^(UIButton *b) {
        [writerTextField resignFirstResponder];
        [writerItemIDField resignFirstResponder];
        NSString *text   = [writerTextField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *itemID = [writerItemIDField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (!text.length)   { setStatus(@"⚠ Enter text to write", NO); return; }
        if (!itemID.length) { setStatus(@"⚠ Enter an item ID",    NO); return; }
        readSpawnPosition();
        float scale   = writerScaleField.text.length   ? [writerScaleField.text floatValue]   : 1.0f;
        float spacing = writerSpacingField.text.length ? [writerSpacingField.text floatValue] : 1.0f;
        if (scale   <= 0) scale   = 1.0f;
        if (spacing <  0) spacing = 1.0f;
        NSString *axisStr = [[writerAxisField.text uppercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        int axis = ([axisStr isEqualToString:@"Z"]) ? 1 : 0;
        spawnTextInWorld(text, itemID, spawnX, spawnY, spawnZ, scale, spacing, axis);
    };
    [writeBtn addTarget:writeBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:writeBtn]; cy += 52+gap;

    // Divider
    UIView *div = [[UIView alloc] initWithFrame:CGRectMake(pad, cy+8, w-pad*2, 1)];
    div.backgroundColor = [UIColor colorWithRed:0.60 green:0.20 blue:0.90 alpha:0.3];
    [content addSubview:div];
    UILabel *gridHdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 22)];
    gridHdr.text = @"🎨  CUSTOM GRID PAINTER";
    gridHdr.textColor = [UIColor colorWithRed:0.85 green:0.55 blue:1.0 alpha:1];
    gridHdr.font = [UIFont boldSystemFontOfSize:13];
    [content addSubview:gridHdr]; cy += 22+gap;

    // Grid cells
    UIColor *cellOff = [UIColor colorWithRed:0.12 green:0.04 blue:0.18 alpha:1];
    UIColor *cellOn  = [UIColor colorWithRed:0.70 green:0.30 blue:1.0 alpha:1];
    CGFloat cs = gridCellSz;

    for (int row = 0; row < GRID_ROWS; row++) {
        for (int col = 0; col < GRID_COLS; col++) {
            CGFloat cx2 = pad + col*(cs+3);
            CGFloat cy2 = cy + row*(cs+3);
            ACBtn *cell = [ACBtn buttonWithType:UIButtonTypeSystem];
            cell.frame = CGRectMake(cx2, cy2, cs, cs);
            cell.backgroundColor = cellOff;
            cell.layer.cornerRadius = 3;
            cell.layer.borderWidth = 0.5;
            cell.layer.borderColor = [UIColor colorWithRed:0.50 green:0.20 blue:0.70 alpha:0.4].CGColor;
            cell.tag = row * GRID_COLS + col;
            UIColor *on = cellOn; UIColor *off = cellOff;
            cell.action = ^(UIButton *b) {
                NSInteger tag = b.tag;
                int r2 = (int)(tag / GRID_COLS);
                int c2 = (int)(tag % GRID_COLS);
                gridCells[r2][c2] = !gridCells[r2][c2];
                b.backgroundColor = gridCells[r2][c2] ? on : off;
                b.layer.borderColor = gridCells[r2][c2]
                    ? [on colorWithAlphaComponent:0.8].CGColor
                    : [UIColor colorWithRed:0.50 green:0.20 blue:0.70 alpha:0.4].CGColor;
            };
            [cell addTarget:cell action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
            [content addSubview:cell];
            gridButtons[row][col] = cell;
        }
    }
    cy += gridH + gap;

    // Grid item ID
    [content addSubview:secLabel(@"GRID ITEM ID", CGRectMake(pad, cy, w-pad*2, labelH))]; cy += labelH+4;
    gridItemIDField = styledField(CGRectMake(pad, cy, w-pad*2, fieldH), @"e.g.  item_rock");
    gridItemIDField.layer.borderColor = [UIColor colorWithRed:0.70 green:0.30 blue:1.0 alpha:0.5].CGColor;
    [content addSubview:gridItemIDField]; cy += fieldH+gap;

    // Grid scale
    [content addSubview:secLabel(@"GRID SCALE (units/cell)", CGRectMake(pad, cy, w-pad*2, labelH))]; cy += labelH+4;
    gridScaleField = numericField(CGRectMake(pad, cy, halfW, fieldH), @"1.0");
    gridScaleField.text = @"1.0";
    gridScaleField.layer.borderColor = [UIColor colorWithRed:0.70 green:0.30 blue:1.0 alpha:0.5].CGColor;
    [content addSubview:gridScaleField]; cy += fieldH+gap;

    // Clear + Spawn buttons
    [content addSubview:makeBtn(@"🗑  Clear Grid",
        [UIColor colorWithRed:0.90 green:0.35 blue:0.35 alpha:1],
        CGRectMake(pad, cy, halfW, 44), ^(UIButton *b) {
            for (int r2 = 0; r2 < GRID_ROWS; r2++)
                for (int c2 = 0; c2 < GRID_COLS; c2++) {
                    gridCells[r2][c2] = NO;
                    if (gridButtons[r2][c2]) {
                        gridButtons[r2][c2].backgroundColor = [UIColor colorWithRed:0.12 green:0.04 blue:0.18 alpha:1];
                        gridButtons[r2][c2].layer.borderColor = [UIColor colorWithRed:0.50 green:0.20 blue:0.70 alpha:0.4].CGColor;
                    }
                }
            setStatus(@"Grid cleared", YES);
        })];

    ACBtn *spawnGridBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    spawnGridBtn.frame = CGRectMake(pad+halfW+8, cy, halfW, 44);
    [spawnGridBtn setTitle:@"🚀  Spawn Grid" forState:UIControlStateNormal];
    [spawnGridBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    spawnGridBtn.backgroundColor = [UIColor colorWithRed:0.38 green:0.10 blue:0.55 alpha:1];
    spawnGridBtn.layer.borderWidth = 1.2;
    spawnGridBtn.layer.borderColor = [UIColor colorWithRed:0.75 green:0.35 blue:1.0 alpha:0.7].CGColor;
    spawnGridBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    spawnGridBtn.action = ^(UIButton *b) {
        [gridItemIDField resignFirstResponder];
        NSString *itemID = [gridItemIDField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (!itemID.length && writerItemIDField.text.length)
            itemID = [writerItemIDField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (!itemID.length) { setStatus(@"⚠ Enter grid item ID", NO); return; }
        readSpawnPosition();
        float gs = gridScaleField.text.length ? [gridScaleField.text floatValue] : 1.0f;
        if (gs <= 0) gs = 1.0f;
        NSString *axisStr = [[writerAxisField.text uppercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        int axis = ([axisStr isEqualToString:@"Z"]) ? 1 : 0;
        spawnGridPattern(itemID, spawnX, spawnY, spawnZ, gs, axis);
    };
    [spawnGridBtn addTarget:spawnGridBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:spawnGridBtn];
    cy += 44+gap;

    // Status label
    writerStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 22)];
    writerStatusLabel.text = @"Type text above and tap Write.";
    writerStatusLabel.textColor = [UIColor colorWithWhite:0.40 alpha:1];
    writerStatusLabel.font = [UIFont fontWithName:@"Menlo" size:10];
    writerStatusLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:writerStatusLabel];

    return sv;
}

static UIScrollView *buildItemsTab(CGFloat w, CGFloat h) {
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    sv.backgroundColor = UIColor.clearColor; 
    sv.alwaysBounceVertical = YES;
    sv.showsVerticalScrollIndicator = YES; 
    sv.delaysContentTouches = NO;
    
    CGFloat pad=16, gap=13, fieldH=46, btnH=52, pickerH=130, qtyH=50, spawnH=60, asyncH=44, fartyH=52;
    CGFloat totalH = gap + 18+4+fieldH+gap + btnH+gap + (22+pickerH)+gap + qtyH+gap + spawnH+gap + asyncH+gap + fartyH+gap + fartyH+gap + fartyH+gap + 22+gap;
    
    UIView *content = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, totalH)];
    [sv addSubview:content]; 
    sv.contentSize = CGSizeMake(w, totalH);
    CGFloat cy = gap;

    [content addSubview:secLabel(@"ITEM ID", CGRectMake(pad, cy, w-pad*2, 18))]; cy += 22;
    idField = styledField(CGRectMake(pad, cy, w-pad*2, fieldH), @"e.g.  item_bat");
    [content addSubview:idField]; cy += fieldH+gap;

    [content addSubview:makeBtn(@"📥  Import JSON",
        [UIColor colorWithRed:0.42 green:0.88 blue:0.55 alpha:1],
        CGRectMake(pad, cy, w-pad*2, btnH), ^(UIButton *b){ openJSONPicker(); })];
    cy += btnH+gap;

    pickerCard = [[UIView alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 22+pickerH)];
    pickerCard.hidden = YES; 
    pickerCard.layer.borderWidth = 1.0;
    pickerCard.layer.borderColor = [UIColor colorWithRed:0.80 green:0.15 blue:0.15 alpha:0.35].CGColor;
    [content addSubview:pickerCard];
    [pickerCard addSubview:secLabel(@"SELECT FROM JSON", CGRectMake(0, 0, w-pad*2, 18))];
    idPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 22, w-pad*2, pickerH)];
    idPicker.backgroundColor = [UIColor colorWithRed:0.14 green:0.04 blue:0.04 alpha:1];
    if (!_pickerDS) _pickerDS = [ACPickerDS new];
    idPicker.dataSource = _pickerDS; 
    idPicker.delegate = _pickerDS;
    [pickerCard addSubview:idPicker]; cy += (22+pickerH)+gap;

    // Quantity selector
    UILabel *qtyTitle = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy+13, 46, 24)];
    qtyTitle.text = @"Qty:"; 
    qtyTitle.textColor = UIColor.whiteColor;
    qtyTitle.font = [UIFont boldSystemFontOfSize:15]; 
    [content addSubview:qtyTitle];
    
    qtyLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad+50, cy+9, 46, 32)];
    qtyLabel.text = @"1"; 
    qtyLabel.textColor = [UIColor colorWithRed:1.0 green:0.65 blue:0.65 alpha:1];
    qtyLabel.font = [UIFont boldSystemFontOfSize:20]; 
    qtyLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:qtyLabel];
    
    CGFloat sw = 40;
    ACBtn *minBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    minBtn.frame = CGRectMake(pad+100, cy+7, sw, sw);
    [minBtn setTitle:@"−" forState:UIControlStateNormal];
    [minBtn setTitleColor:[UIColor colorWithRed:1 green:0.42 blue:0.42 alpha:1] forState:UIControlStateNormal];
    minBtn.backgroundColor = [UIColor colorWithWhite:0.14 alpha:1]; 
    minBtn.layer.borderWidth = 1;
    minBtn.layer.borderColor = [[UIColor colorWithRed:1 green:0.42 blue:0.42 alpha:1] colorWithAlphaComponent:0.4].CGColor;
    minBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    minBtn.action = ^(UIButton *b){ 
        if (spawnQty>1){ 
            spawnQty--; 
            qtyLabel.text=[NSString stringWithFormat:@"%ld",(long)spawnQty]; 
        } 
    };
    [minBtn addTarget:minBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:minBtn];
    
    ACBtn *plusBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    plusBtn.frame = CGRectMake(pad+146, cy+7, sw, sw);
    [plusBtn setTitle:@"+" forState:UIControlStateNormal];
    [plusBtn setTitleColor:[UIColor colorWithRed:0.42 green:0.88 blue:0.55 alpha:1] forState:UIControlStateNormal];
    plusBtn.backgroundColor = [UIColor colorWithWhite:0.14 alpha:1]; 
    plusBtn.layer.borderWidth = 1;
    plusBtn.layer.borderColor = [[UIColor colorWithRed:0.42 green:0.88 blue:0.55 alpha:1] colorWithAlphaComponent:0.4].CGColor;
    plusBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    plusBtn.action = ^(UIButton *b){ 
        if (spawnQty<99){ 
            spawnQty++; 
            qtyLabel.text=[NSString stringWithFormat:@"%ld",(long)spawnQty]; 
        } 
    };
    [plusBtn addTarget:plusBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:plusBtn]; cy += qtyH+gap;

    // SPAWN button
    ACBtn *spawnBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    spawnBtn.frame = CGRectMake(pad, cy, w-pad*2, spawnH);
    [spawnBtn setTitle:@"✦  SPAWN" forState:UIControlStateNormal];
    [spawnBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    spawnBtn.backgroundColor = [UIColor colorWithRed:0.65 green:0.08 blue:0.08 alpha:1];
    spawnBtn.layer.borderWidth = 1.5;
    spawnBtn.layer.borderColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.25 alpha:1].CGColor;
    spawnBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    spawnBtn.action = ^(UIButton *b) {
        NSString *raw = [idField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (!raw.length) { setStatus(@"⚠ Enter an item ID first.", NO); return; }
        [idField resignFirstResponder];

        float    itemHue    = -1.0f;
        NSArray *childrenIDs = nil;
        if (jsonIDs.count) {
            NSInteger idx = [idPicker selectedRowInComponent:0];
            if (idx >= 0 && idx < (NSInteger)jsonIDs.count) {
                NSValue *val = jsonIDs[idx]; 
                JSONItem item; 
                [val getValue:&item];
                if ([item.itemID isEqualToString:raw]) { 
                    itemHue = item.hue; 
                    childrenIDs = item.children; 
                }
            }
        }

        if (!_resolved) { 
            enqueueSpawn(raw, itemHue, NO, spawnQty); 
            return; 
        }

        NSInteger qty = spawnQty;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __block NSString *lastErr = nil;
            for (NSInteger i = 0; i < qty; i++) {
                if (i > 0) [NSThread sleepForTimeInterval:0.08];
                NSString *err = doSpawnItem(raw, itemHue, NO);
                if (err) { 
                    lastErr = err; 
                    break; 
                }
                for (NSString *cid in childrenIDs) doSpawnItem(cid, -1.0f, NO);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (lastErr) {
                    setStatus([NSString stringWithFormat:@"⚠ %@", lastErr], NO);
                } else {
                    NSString *msg = [NSString stringWithFormat:@"✓ Spawned x%ld — %@", (long)qty, raw];
                    if (itemHue >= 0.0f) msg = [msg stringByAppendingFormat:@" (hue:%.1f)", itemHue];
                    if (childrenIDs.count) msg = [msg stringByAppendingFormat:@" [+%lu children]", (unsigned long)childrenIDs.count];
                    setStatus(msg, YES);
                }
            });
        });
    };
    [spawnBtn addTarget:spawnBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:spawnBtn]; cy += spawnH+gap;

    // SPAWN ASYNC button
    ACBtn *asyncBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    asyncBtn.frame = CGRectMake(pad, cy, w-pad*2, asyncH);
    [asyncBtn setTitle:@"⟳  Spawn Async  (Networked)" forState:UIControlStateNormal];
    [asyncBtn setTitleColor:[UIColor colorWithRed:0.55 green:0.85 blue:1.0 alpha:1] forState:UIControlStateNormal];
    asyncBtn.backgroundColor = [UIColor colorWithRed:0.06 green:0.20 blue:0.35 alpha:1];
    asyncBtn.layer.borderWidth = 1.2;
    asyncBtn.layer.borderColor = [UIColor colorWithRed:0.30 green:0.65 blue:1.0 alpha:0.5].CGColor;
    asyncBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    asyncBtn.action = ^(UIButton *b) {
        NSString *raw = [idField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (!raw.length) { setStatus(@"⚠ Enter an item ID first.", NO); return; }
        [idField resignFirstResponder];

        float    itemHue    = -1.0f;
        NSArray *childrenIDs = nil;
        if (jsonIDs.count) {
            NSInteger idx = [idPicker selectedRowInComponent:0];
            if (idx >= 0 && idx < (NSInteger)jsonIDs.count) {
                NSValue *val = jsonIDs[idx]; 
                JSONItem item; 
                [val getValue:&item];
                if ([item.itemID isEqualToString:raw]) { 
                    itemHue = item.hue; 
                    childrenIDs = item.children; 
                }
            }
        }

        if (!_resolved) { 
            enqueueSpawn(raw, itemHue, YES, spawnQty); 
            return; 
        }

        NSInteger qty = spawnQty;
        for (NSInteger i = 0; i < qty; i++) {
            NSString *err = doSpawnItem(raw, itemHue, YES);
            if (err) { 
                setStatus([NSString stringWithFormat:@"⚠ Async: %@", err], NO); 
                return; 
            }
            for (NSString *cid in childrenIDs) doSpawnItem(cid, -1.0f, YES);
        }
        NSString *msg = [NSString stringWithFormat:@"✓ Async x%ld — %@", (long)qty, raw];
        if (childrenIDs.count) msg = [msg stringByAppendingFormat:@" [+%lu children]", (unsigned long)childrenIDs.count];
        setStatus(msg, YES);
    };
    [asyncBtn addTarget:asyncBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:asyncBtn]; cy += asyncH+gap;

    // Fart Power
    ACBtn *fBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    fBtn.frame = CGRectMake(pad, cy, w-pad*2, fartyH);
    [fBtn setTitle:@"💨  Enable Fart Power" forState:UIControlStateNormal];
    [fBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    fBtn.backgroundColor = [UIColor colorWithRed:0.30 green:0.20 blue:0.05 alpha:1];
    fBtn.layer.borderWidth = 1.5; 
    fBtn.layer.borderColor = [UIColor colorWithRed:0.70 green:0.55 blue:0.10 alpha:1].CGColor;
    fBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    fBtn.action = ^(UIButton *b) {
        fartyEnabled = !fartyEnabled;
        [b setTitle:fartyEnabled ? @"💨  Fart Power: ON" : @"💨  Enable Fart Power" forState:UIControlStateNormal];
        b.backgroundColor = fartyEnabled ? [UIColor colorWithRed:0.20 green:0.45 blue:0.10 alpha:1]
                                         : [UIColor colorWithRed:0.30 green:0.20 blue:0.05 alpha:1];
        setFarty(fartyEnabled);
    };
    [fBtn addTarget:fBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    fartyBtn = fBtn; 
    [content addSubview:fBtn]; cy += fartyH+gap;
    
    // Yeet Spam Button
    ACBtn *yeetBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    yeetBtn.frame = CGRectMake(pad, cy, w-pad*2, fartyH);
    [yeetBtn setTitle:@"⚡  Toggle Yeet Spam" forState:UIControlStateNormal];
    [yeetBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    yeetBtn.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.40 alpha:1];
    yeetBtn.layer.borderWidth = 1.5; 
    yeetBtn.layer.borderColor = [UIColor colorWithRed:0.50 green:0.50 blue:0.90 alpha:1].CGColor;
    yeetBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    yeetBtn.action = ^(UIButton *b) {
        yeetSpamEnabled = !yeetSpamEnabled;
        [b setTitle:yeetSpamEnabled ? @"⚡  Yeet Spam: ON (tap to stop)" : @"⚡  Toggle Yeet Spam" forState:UIControlStateNormal];
        b.backgroundColor = yeetSpamEnabled ? [UIColor colorWithRed:0.60 green:0.20 blue:0.80 alpha:1]
                                          : [UIColor colorWithRed:0.20 green:0.20 blue:0.40 alpha:1];
        startYeetSpam(yeetSpamEnabled);
    };
    [yeetBtn addTarget:yeetBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    yeetSpamBtn = yeetBtn; 
    [content addSubview:yeetBtn]; cy += fartyH+gap;
    
    // Kill Spam Button
    ACBtn *killBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    killBtn.frame = CGRectMake(pad, cy, w-pad*2, fartyH);
    [killBtn setTitle:@"💀  Toggle Kill Spam" forState:UIControlStateNormal];
    [killBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    killBtn.backgroundColor = [UIColor colorWithRed:0.40 green:0.20 blue:0.20 alpha:1];
    killBtn.layer.borderWidth = 1.5; 
    killBtn.layer.borderColor = [UIColor colorWithRed:0.90 green:0.50 blue:0.50 alpha:1].CGColor;
    killBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    killBtn.action = ^(UIButton *b) {
        killSpamEnabled = !killSpamEnabled;
        [b setTitle:killSpamEnabled ? @"💀  Kill Spam: ON (tap to stop)" : @"💀  Toggle Kill Spam" forState:UIControlStateNormal];
        b.backgroundColor = killSpamEnabled ? [UIColor colorWithRed:0.80 green:0.10 blue:0.10 alpha:1]
                                          : [UIColor colorWithRed:0.40 green:0.20 blue:0.20 alpha:1];
        startKillSpam(killSpamEnabled);
    };
    [killBtn addTarget:killBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    killSpamBtn = killBtn; 
    [content addSubview:killBtn]; cy += fartyH+gap;

    statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 22)];
    statusLabel.text = @"Enter an item ID to spawn.";
    statusLabel.textColor = [UIColor colorWithWhite:0.42 alpha:1];
    statusLabel.font = [UIFont fontWithName:@"Menlo" size:11];
    statusLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:statusLabel];
    return sv;
}

static UIScrollView *buildMobsTab(CGFloat w, CGFloat h) {
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    sv.backgroundColor = UIColor.clearColor; 
    sv.alwaysBounceVertical = YES;
    
    CGFloat pad=16, gap=14, fieldH=46, labelH=18;
    CGFloat totalH = gap+22+gap + labelH+4+fieldH+gap + labelH+4+fieldH+gap + 60+gap + 52+gap + 60+gap;
    
    UIView *content = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, totalH)];
    [sv addSubview:content]; 
    sv.contentSize = CGSizeMake(w, totalH);
    CGFloat cy = gap;
    
    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 22)];
    hdr.text = @"MOB SPAWNER"; 
    hdr.textColor = [UIColor colorWithRed:0.95 green:0.35 blue:0.35 alpha:1];
    hdr.font = [UIFont boldSystemFontOfSize:13]; 
    [content addSubview:hdr]; cy += 22+6;
    
    [content addSubview:secLabel(@"MOB ID  (integer from dump MobID enum)", CGRectMake(pad, cy, w-pad*2, labelH))]; cy += labelH+4;
    mobIDField = styledField(CGRectMake(pad, cy, w-pad*2, fieldH), @"e.g.  0  or  3");
    mobIDField.keyboardType = UIKeyboardTypeNumberPad; 
    mobIDField.text = @"0";
    [content addSubview:mobIDField]; cy += fieldH+gap;
    
    [content addSubview:secLabel(@"SPAWN RADIUS  (metres from player)", CGRectMake(pad, cy, w-pad*2, labelH))]; cy += labelH+4;
    mobRadiusField = numericField(CGRectMake(pad, cy, w-pad*2, fieldH), @"default  15");
    mobRadiusField.text = @"15"; 
    [content addSubview:mobRadiusField]; cy += fieldH+gap;
    
    UIView *infoCard = [[UIView alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 60)];
    infoCard.backgroundColor = [UIColor colorWithRed:0.18 green:0.05 blue:0.05 alpha:1];
    infoCard.layer.borderWidth = 1; 
    infoCard.layer.borderColor = [UIColor colorWithRed:0.80 green:0.15 blue:0.15 alpha:0.35].CGColor;
    [content addSubview:infoCard];
    UILabel *info = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, w-pad*2-20, 48)];
    info.text = @"Uses SpawnMobNearbyPlayerAsync — no position\nneeded, mob appears near you automatically.\nFallback: SpawnMobAsync uses Settings position.";
    info.textColor = [UIColor colorWithWhite:0.55 alpha:1]; 
    info.font = [UIFont systemFontOfSize:11]; 
    info.numberOfLines = 0;
    [infoCard addSubview:info]; cy += 60+gap;
    
    ACBtn *mobBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    mobBtn.frame = CGRectMake(pad, cy, w-pad*2, 52);
    [mobBtn setTitle:@"🐾  SPAWN MOB" forState:UIControlStateNormal];
    [mobBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    mobBtn.backgroundColor = [UIColor colorWithRed:0.45 green:0.12 blue:0.55 alpha:1];
    mobBtn.layer.borderWidth = 1.5; 
    mobBtn.layer.borderColor = [UIColor colorWithRed:0.75 green:0.30 blue:0.90 alpha:1].CGColor;
    mobBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    mobBtn.action = ^(UIButton *b) {
        NSString *mid = [mobIDField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (!mid.length) { setStatus(@"⚠ Enter a mob ID.", NO); return; }
        [mobIDField resignFirstResponder]; 
        [mobRadiusField resignFirstResponder];
        float radius = mobRadiusField.text.length ? (float)[mobRadiusField.text floatValue] : 15.0f;
        if (radius <= 0) radius = 15.0f;
        readSpawnPosition(); 
        spawnMobNearbyPlayer(mid, radius);
    };
    [mobBtn addTarget:mobBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:mobBtn]; cy += 52+gap;
    
    UIView *hintCard = [[UIView alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 60)];
    hintCard.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.20 alpha:1];
    hintCard.layer.borderWidth = 1; 
    hintCard.layer.borderColor = [UIColor colorWithRed:0.40 green:0.40 blue:0.80 alpha:0.35].CGColor;
    [content addSubview:hintCard];
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, w-pad*2-20, 48)];
    hint.text = @"Find MobID values by searching your dump\nfor 'public enum MobID' — use the integer\nvalue next to each mob name.";
    hint.textColor = [UIColor colorWithWhite:0.55 alpha:1]; 
    hint.font = [UIFont systemFontOfSize:11]; 
    hint.numberOfLines = 0;
    [hintCard addSubview:hint];
    return sv;
}

static UIScrollView *buildCameraTab(CGFloat w, CGFloat h) {
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    sv.backgroundColor = UIColor.clearColor; 
    sv.alwaysBounceVertical = YES;
    
    CGFloat pad=16, gap=14;
    CGFloat totalH = gap+22+gap + 60+gap + 52+gap + 44+gap + 44+gap + 18+gap + 160+gap + 60+gap;
    
    UIView *content = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, totalH)];
    [sv addSubview:content]; 
    sv.contentSize = CGSizeMake(w, totalH);
    CGFloat cy = gap;
    
    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 22)];
    hdr.text = @"CAMERA POSITION LOGGER";
    hdr.textColor = [UIColor colorWithRed:0.35 green:0.75 blue:1.0 alpha:1];
    hdr.font = [UIFont boldSystemFontOfSize:13]; 
    [content addSubview:hdr]; cy += 22+gap;
    
    UIView *posCard = [[UIView alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 60)];
    posCard.backgroundColor = [UIColor colorWithRed:0.05 green:0.10 blue:0.20 alpha:1];
    posCard.layer.cornerRadius = 8; 
    posCard.layer.borderWidth = 1.5;
    posCard.layer.borderColor = [UIColor colorWithRed:0.25 green:0.65 blue:1.0 alpha:0.7].CGColor;
    [content addSubview:posCard];
    UILabel *posHdr = [[UILabel alloc] initWithFrame:CGRectMake(10, 4, w-pad*2-20, 16)];
    posHdr.text = @"LIVE POSITION"; 
    posHdr.textColor = [UIColor colorWithRed:0.35 green:0.75 blue:1.0 alpha:0.7];
    posHdr.font = [UIFont boldSystemFontOfSize:9]; 
    [posCard addSubview:posHdr];
    camPosLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 20, w-pad*2-20, 34)];
    camPosLabel.text = @"X:   —         Y:   —         Z:   —";
    camPosLabel.textColor = UIColor.whiteColor; 
    camPosLabel.font = [UIFont fontWithName:@"Menlo" size:13];
    camPosLabel.adjustsFontSizeToFitWidth = YES; 
    [posCard addSubview:camPosLabel]; cy += 60+gap;
    
    ACBtn *trackBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    trackBtn.frame = CGRectMake(pad, cy, w-pad*2, 52);
    [trackBtn setTitle:@"▶  Start Tracking" forState:UIControlStateNormal];
    [trackBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    trackBtn.backgroundColor = [UIColor colorWithRed:0.08 green:0.35 blue:0.55 alpha:1];
    trackBtn.layer.borderWidth = 1.5;
    trackBtn.layer.borderColor = [UIColor colorWithRed:0.25 green:0.65 blue:1.0 alpha:0.8].CGColor;
    trackBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    trackBtn.action = ^(UIButton *b) {
        camTracking = !camTracking;
        if (camTracking) {
            startCameraTracking();
            [b setTitle:@"⏹  Stop Tracking" forState:UIControlStateNormal];
            b.backgroundColor = [UIColor colorWithRed:0.55 green:0.08 blue:0.08 alpha:1];
            b.layer.borderColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.25 alpha:0.8].CGColor;
        } else {
            stopCameraTracking();
            [b setTitle:@"▶  Start Tracking" forState:UIControlStateNormal];
            b.backgroundColor = [UIColor colorWithRed:0.08 green:0.35 blue:0.55 alpha:1];
            b.layer.borderColor = [UIColor colorWithRed:0.25 green:0.65 blue:1.0 alpha:0.8].CGColor;
        }
    };
    [trackBtn addTarget:trackBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    camTrackBtn = trackBtn; 
    [content addSubview:trackBtn]; cy += 52+gap;
    
    [content addSubview:makeBtn(@"📸  Snapshot — Log Once",
        [UIColor colorWithRed:0.35 green:0.75 blue:1.0 alpha:1],
        CGRectMake(pad, cy, w-pad*2, 44), ^(UIButton *b){ pollCameraPosition(); })]; cy += 44+gap;
    
    [content addSubview:makeBtn(@"📌  Copy Position → Spawn Settings",
        [UIColor colorWithRed:0.90 green:0.70 blue:0.20 alpha:1],
        CGRectMake(pad, cy, w-pad*2, 44), ^(UIButton *b){
            Vector3 pos = getCameraPosition();
            spawnX = pos.x; spawnY = pos.y; spawnZ = pos.z;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (xField) xField.text = [NSString stringWithFormat:@"%.3f", pos.x];
                if (yField) yField.text = [NSString stringWithFormat:@"%.3f", pos.y];
                if (zField) zField.text = [NSString stringWithFormat:@"%.3f", pos.z];
            });
            setStatus([NSString stringWithFormat:@"✓ Spawn set to camera (%.1f, %.1f, %.1f)", pos.x, pos.y, pos.z], YES);
        })]; cy += 44+gap;
    
    [content addSubview:secLabel(@"POSITION LOG  (last 8 readings)", CGRectMake(pad, cy, w-pad*2, 18))]; cy += 18+gap;
    
    UIView *logBox = [[UIView alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 160)];
    logBox.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.10 alpha:1];
    logBox.layer.borderWidth = 1; 
    logBox.layer.borderColor = [UIColor colorWithRed:0.25 green:0.65 blue:1.0 alpha:0.3].CGColor;
    logBox.layer.cornerRadius = 6; 
    [content addSubview:logBox];
    camLogLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 8, w-pad*2-16, 144)];
    camLogLabel.text = @"No data yet — tap Snapshot or Start Tracking.";
    camLogLabel.textColor = [UIColor colorWithWhite:0.50 alpha:1]; 
    camLogLabel.font = [UIFont fontWithName:@"Menlo" size:10];
    camLogLabel.numberOfLines = 0; 
    camLogLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [logBox addSubview:camLogLabel]; cy += 160+gap;
    
    UIView *infoCard2 = [[UIView alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 60)];
    infoCard2.backgroundColor = [UIColor colorWithRed:0.05 green:0.10 blue:0.18 alpha:1];
    infoCard2.layer.borderWidth = 1; 
    infoCard2.layer.borderColor = [UIColor colorWithRed:0.25 green:0.65 blue:1.0 alpha:0.25].CGColor;
    [content addSubview:infoCard2];
    UILabel *infoTxt = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, w-pad*2-20, 48)];
    infoTxt.text = @"Reads from Camera.main.transform.position\nvia UnityEngine.CoreModule Il2Cpp API.\nPoll interval: 0.25s.";
    infoTxt.textColor = [UIColor colorWithWhite:0.45 alpha:1]; 
    infoTxt.font = [UIFont systemFontOfSize:10]; 
    infoTxt.numberOfLines = 0;
    [infoCard2 addSubview:infoTxt];
    return sv;
}

static ACBtn *makeSceneryToggle(NSString *emoji, NSString *label, NSString *desc,
                                UIColor *accent, CGRect frame,
                                BOOL *statePtr, void(^setter)(BOOL)) {
    ACBtn *b = [ACBtn buttonWithType:UIButtonTypeSystem];
    b.frame = frame; 
    b.layer.cornerRadius = 10; 
    b.layer.borderWidth = 1.8;
    b.layer.borderColor = [accent colorWithAlphaComponent:0.55].CGColor;
    b.backgroundColor = [UIColor colorWithWhite:0.10 alpha:1]; 
    b.clipsToBounds = YES;
    
    UILabel *el = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, 48, frame.size.height)];
    el.text = emoji; 
    el.font = [UIFont systemFontOfSize:30]; 
    el.textAlignment = NSTextAlignmentCenter;
    el.userInteractionEnabled = NO; 
    [b addSubview:el];
    
    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(68, 10, frame.size.width-80, 22)];
    tl.text = label; 
    tl.font = [UIFont boldSystemFontOfSize:15]; 
    tl.textColor = UIColor.whiteColor;
    tl.userInteractionEnabled = NO; 
    [b addSubview:tl];
    
    UILabel *dl = [[UILabel alloc] initWithFrame:CGRectMake(68, 32, frame.size.width-80, 18)];
    dl.text = desc; 
    dl.font = [UIFont systemFontOfSize:11]; 
    dl.textColor = [UIColor colorWithWhite:0.55 alpha:1];
    dl.userInteractionEnabled = NO; 
    [b addSubview:dl];
    
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(frame.size.width-22, frame.size.height/2-6, 12, 12)];
    dot.layer.cornerRadius = 6; 
    dot.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1];
    dot.tag = 991; 
    dot.userInteractionEnabled = NO; 
    [b addSubview:dot];
    
    b.action = ^(UIButton *btn) {
        *statePtr = !(*statePtr); 
        BOOL on = *statePtr; 
        setter(on);
        btn.backgroundColor = on ? [accent colorWithAlphaComponent:0.22] : [UIColor colorWithWhite:0.10 alpha:1];
        btn.layer.borderColor = on ? [accent colorWithAlphaComponent:1.0].CGColor : [accent colorWithAlphaComponent:0.55].CGColor;
        [btn viewWithTag:991].backgroundColor = on ? accent : [UIColor colorWithWhite:0.25 alpha:1];
    };
    [b addTarget:b action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static UIScrollView *buildSceneryTab(CGFloat w, CGFloat h) {
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    sv.backgroundColor = UIColor.clearColor; 
    sv.alwaysBounceVertical = YES; 
    sv.showsVerticalScrollIndicator = YES;
    
    CGFloat pad=14, gap=12, btnH=62;
    CGFloat totalH = gap+22+gap + (btnH+gap)*4 + 70+gap;
    
    UIView *content = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, totalH)];
    [sv addSubview:content]; 
    sv.contentSize = CGSizeMake(w, totalH);
    CGFloat cy = gap;
    
    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 22)];
    hdr.text = @"🌍  SCENERY OVERRIDE"; 
    hdr.textColor = [UIColor colorWithRed:0.55 green:0.88 blue:0.65 alpha:1];
    hdr.font = [UIFont boldSystemFontOfSize:14]; 
    [content addSubview:hdr]; cy += 22+gap;
    
    [content addSubview:makeSceneryToggle(@"🎃", @"Halloween", @"Forces Halloween event appearance",
        [UIColor colorWithRed:0.90 green:0.45 blue:0.05 alpha:1],
        CGRectMake(pad, cy, w-pad*2, btnH), &sceneryHalloween, ^(BOOL on){ setSceneryHalloween(on); })]; cy += btnH+gap;
    
    [content addSubview:makeSceneryToggle(@"🦃", @"Thanksgiving", @"Forces Thanksgiving event appearance",
        [UIColor colorWithRed:0.78 green:0.42 blue:0.08 alpha:1],
        CGRectMake(pad, cy, w-pad*2, btnH), &sceneryThanksgiving, ^(BOOL on){ setSceneryThanksgiving(on); })]; cy += btnH+gap;
    
    [content addSubview:makeSceneryToggle(@"❄️", @"Snow Storm", @"Forces heavy snow storm weather",
        [UIColor colorWithRed:0.55 green:0.82 blue:1.00 alpha:1],
        CGRectMake(pad, cy, w-pad*2, btnH), &scenerySnowStorm, ^(BOOL on){ setScenerySnowStorm(on); })]; cy += btnH+gap;
    
    [content addSubview:makeSceneryToggle(@"🌧️", @"Heavy Rain", @"Forces heavy rain weather",
        [UIColor colorWithRed:0.28 green:0.58 blue:1.00 alpha:1],
        CGRectMake(pad, cy, w-pad*2, btnH), &sceneryHeavyRain, ^(BOOL on){ setSceneryHeavyRain(on); })]; cy += btnH+gap;
    
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 70)];
    card.backgroundColor = [UIColor colorWithRed:0.06 green:0.12 blue:0.08 alpha:1];
    card.layer.borderWidth = 1; 
    card.layer.borderColor = [UIColor colorWithRed:0.35 green:0.70 blue:0.45 alpha:0.40].CGColor;
    card.layer.cornerRadius = 8; 
    [content addSubview:card];
    UILabel *cardTxt = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, w-pad*2-20, 58)];
    cardTxt.text = @"Patches AppFlags getter methods directly in\nmemory using RVAs from your dump. The\ngetter always returns the forced value until\nthe app restarts or you toggle it off.";
    cardTxt.textColor = [UIColor colorWithWhite:0.48 alpha:1]; 
    cardTxt.font = [UIFont systemFontOfSize:10];
    cardTxt.numberOfLines = 0; 
    [card addSubview:cardTxt];
    return sv;
}

static UIScrollView *buildSettingsTab(CGFloat w, CGFloat h) {
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    sv.backgroundColor = UIColor.clearColor; 
    sv.alwaysBounceVertical = YES;
    
    CGFloat pad=16, gap=14, fH=46, labelH=18;
    CGFloat totalH = gap+22 + (labelH+4+fH+gap)*3 + 52+gap + 60+gap + 22+6+52+gap+52+gap;
    
    UIView *content = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, totalH)];
    [sv addSubview:content]; 
    sv.contentSize = CGSizeMake(w, totalH);
    CGFloat cy = gap;
    
    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 22)];
    hdr.text = @"SPAWN POSITION"; 
    hdr.textColor = [UIColor colorWithRed:0.95 green:0.35 blue:0.35 alpha:1];
    hdr.font = [UIFont boldSystemFontOfSize:13]; 
    [content addSubview:hdr]; cy += 22+6;
    
    #define MAKE_AXIS_FIELD(axisStr, hintStr, outField, defaultVal) \
    do { \
        UILabel *_lbl = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, 30, labelH)]; \
        _lbl.text = axisStr; _lbl.textColor = [UIColor colorWithRed:0.95 green:0.35 blue:0.35 alpha:1]; \
        _lbl.font = [UIFont boldSystemFontOfSize:13]; [content addSubview:_lbl]; \
        UILabel *_hint = [[UILabel alloc] initWithFrame:CGRectMake(pad+34, cy, w-pad*2-34, labelH)]; \
        _hint.textColor = [UIColor colorWithWhite:0.45 alpha:1]; \
        _hint.font = [UIFont systemFontOfSize:11]; _hint.text = hintStr; [content addSubview:_hint]; \
        cy += labelH+4; \
        UITextField *_field = numericField(CGRectMake(pad, cy, w-pad*2, fH), \
            [NSString stringWithFormat:@"%.1f", (float)(defaultVal)]); \
        _field.text = [NSString stringWithFormat:@"%.1f", (float)(defaultVal)]; \
        [content addSubview:_field]; outField = _field; cy += fH+gap; \
    } while(0)
    
    MAKE_AXIS_FIELD(@"X", @"<- left / right ->",      xField, 0.0f);
    MAKE_AXIS_FIELD(@"Y", @"down / up  (0 = ground)", yField, 0.0f);
    MAKE_AXIS_FIELD(@"Z", @"forward / backward",      zField, 0.0f);
    #undef MAKE_AXIS_FIELD
    
    [content addSubview:makeBtn(@"↺  Reset to 0, 0, 0",
        [UIColor colorWithRed:0.90 green:0.25 blue:0.25 alpha:1],
        CGRectMake(pad, cy, w-pad*2, 52),
        ^(UIButton *b) {
            spawnX = spawnY = spawnZ = 0.0f;
            if (xField) xField.text = @"0.0";
            if (yField) yField.text = @"0.0";
            if (zField) zField.text = @"0.0";
        })]; cy += 52+gap;
    
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 60)];
    card.backgroundColor = [UIColor colorWithRed:0.18 green:0.05 blue:0.05 alpha:1];
    card.layer.borderWidth = 1; 
    card.layer.borderColor = [UIColor colorWithRed:0.80 green:0.15 blue:0.15 alpha:0.35].CGColor;
    [content addSubview:card];
    UILabel *cardInfo = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, w-pad*2-20, 48)];
    cardInfo.text = @"World-space position used by SPAWN and\nSpawn Async. Use Camera tab to copy your\ncurrent position directly into these fields.";
    cardInfo.textColor = [UIColor colorWithWhite:0.55 alpha:1]; 
    cardInfo.font = [UIFont systemFontOfSize:11];
    cardInfo.numberOfLines = 0; 
    [card addSubview:cardInfo];
    cy += 60+gap;

    // Display mode
    UILabel *modeHdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 22)];
    modeHdr.text = @"DISPLAY MODE";
    modeHdr.textColor = [UIColor colorWithRed:0.95 green:0.35 blue:0.35 alpha:1];
    modeHdr.font = [UIFont boldSystemFontOfSize:13];
    [content addSubview:modeHdr]; cy += 22+6;

    __block ACBtn *iphoneBtn = nil;
    __block ACBtn *ipadBtn   = nil;
    UIColor *modeActiveCol   = [UIColor colorWithRed:0.65 green:0.10 blue:0.10 alpha:1];
    UIColor *modeInactiveCol = [UIColor colorWithWhite:0.12 alpha:1];
    CGFloat halfBtnW = (w - pad*2 - 10) / 2.0;

    ACBtn *_iphoneBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    _iphoneBtn.frame = CGRectMake(pad, cy, halfBtnW, 52);
    [_iphoneBtn setTitle:@"📱  iPhone" forState:UIControlStateNormal];
    [_iphoneBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _iphoneBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    _iphoneBtn.backgroundColor = (displayMode == 0) ? modeActiveCol : modeInactiveCol;
    _iphoneBtn.layer.borderWidth = 1.5;
    _iphoneBtn.layer.borderColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:0.7].CGColor;
    _iphoneBtn.layer.cornerRadius = 8;
    _iphoneBtn.action = ^(UIButton *b) {
        applyDisplayMode(0);
        iphoneBtn.backgroundColor = modeActiveCol;
        ipadBtn.backgroundColor   = modeInactiveCol;
        setStatus(@"📱 iPhone mode", YES);
    };
    [_iphoneBtn addTarget:_iphoneBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_iphoneBtn];
    iphoneBtn = _iphoneBtn;

    ACBtn *_ipadBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    _ipadBtn.frame = CGRectMake(pad + halfBtnW + 10, cy, halfBtnW, 52);
    [_ipadBtn setTitle:@"🖥  iPad" forState:UIControlStateNormal];
    [_ipadBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _ipadBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    _ipadBtn.backgroundColor = (displayMode == 1) ? modeActiveCol : modeInactiveCol;
    _ipadBtn.layer.borderWidth = 1.5;
    _ipadBtn.layer.borderColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:0.7].CGColor;
    _ipadBtn.layer.cornerRadius = 8;
    _ipadBtn.action = ^(UIButton *b) {
        applyDisplayMode(1);
        ipadBtn.backgroundColor   = modeActiveCol;
        iphoneBtn.backgroundColor = modeInactiveCol;
        setStatus(@"🖥 iPad mode", YES);
    };
    [_ipadBtn addTarget:_ipadBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_ipadBtn];
    ipadBtn = _ipadBtn;
    cy += 52+gap;

    UIView *modeCard = [[UIView alloc] initWithFrame:CGRectMake(pad, cy, w-pad*2, 52)];
    modeCard.backgroundColor = [UIColor colorWithRed:0.10 green:0.05 blue:0.05 alpha:1];
    modeCard.layer.borderWidth = 1;
    modeCard.layer.borderColor = [UIColor colorWithRed:0.80 green:0.15 blue:0.15 alpha:0.25].CGColor;
    [content addSubview:modeCard];
    UILabel *modeTxt = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, w-pad*2-20, 40)];
    modeTxt.text = @"iPad mode expands the panel to fit larger\nscreens and prevents layout crashes on iPad.";
    modeTxt.textColor = [UIColor colorWithWhite:0.48 alpha:1];
    modeTxt.font = [UIFont systemFontOfSize:10]; 
    modeTxt.numberOfLines = 0;
    [modeCard addSubview:modeTxt];

    return sv;
}

#pragma mark - Menu Construction

static void createMenuPanel(void) {
    if (!jsonIDs) jsonIDs = [NSMutableArray array];
    CGRect scr = UIScreen.mainScreen.bounds;
    CGFloat w = scr.size.width * 0.80, pH = scr.size.height * 0.80;
    CGFloat x = (scr.size.width - w) / 2.0, y = (scr.size.height - pH) / 2.0;
    
    ACPanView *panel = [[ACPanView alloc] initWithFrame:CGRectMake(x, y, w, pH)];
    panel.backgroundColor = [UIColor colorWithRed:0.65 green:0.08 blue:0.08 alpha:0.97];
    panel.layer.cornerRadius = 16; 
    panel.layer.borderWidth = 1.8;
    panel.layer.borderColor = [UIColor colorWithRed:1.0 green:0.20 blue:0.20 alpha:0.9].CGColor;
    panel.clipsToBounds = YES; 
    panel.hidden = YES; 
    panel.alpha = 0; 
    menuPanel = panel;
    
    UIPanGestureRecognizer *pg = [[UIPanGestureRecognizer alloc] initWithTarget:panel action:@selector(handlePan:)];
    [panel addGestureRecognizer:pg];
    
    CGFloat titleH = 52;
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, titleH)];
    titleBar.backgroundColor = [UIColor colorWithRed:0.80 green:0.10 blue:0.10 alpha:1]; 
    [panel addSubview:titleBar];
    
    UIView *accent = [[UIView alloc] initWithFrame:CGRectMake(0, titleH-2, w, 2)];
    accent.backgroundColor = [UIColor colorWithRed:1.0 green:0.30 blue:0.30 alpha:1]; 
    [titleBar addSubview:accent];
    
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w, titleH-2)];
    titleLbl.text = @"VYRO CLIENT"; 
    titleLbl.textColor = UIColor.whiteColor;
    titleLbl.font = [UIFont boldSystemFontOfSize:17]; 
    titleLbl.textAlignment = NSTextAlignmentCenter; 
    [titleBar addSubview:titleLbl];
    
    ACBtn *xBtn = [ACBtn buttonWithType:UIButtonTypeSystem];
    xBtn.frame = CGRectMake(8, 8, 34, 34);
    xBtn.backgroundColor = [UIColor colorWithRed:0.55 green:0.08 blue:0.08 alpha:1]; 
    xBtn.layer.cornerRadius = 8;
    [xBtn setTitle:@"✕" forState:UIControlStateNormal]; 
    [xBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    xBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14]; 
    xBtn.action = ^(UIButton *b){ toggleMenu(); };
    [xBtn addTarget:xBtn action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside]; 
    [titleBar addSubview:xBtn];
    
    CGFloat tabBarY = titleH, tabBarH = 36;
    UIView *tabBar = [[UIView alloc] initWithFrame:CGRectMake(0, tabBarY, w, tabBarH)];
    tabBar.backgroundColor = [UIColor colorWithRed:0.60 green:0.10 blue:0.10 alpha:1]; 
    [panel addSubview:tabBar];
    
    UIView *tabSep = [[UIView alloc] initWithFrame:CGRectMake(0, tabBarH-1, w, 1)];
    tabSep.backgroundColor = [UIColor colorWithRed:1.0 green:0.20 blue:0.20 alpha:0.4]; 
    [tabBar addSubview:tabSep];
    
    CGFloat sixth = w / 6.0;
    NSArray *tabTitles = @[@"Items", @"Mobs", @"Cam", @"Scene", @"Set", @"Write"];
    NSMutableArray *tabBtns = [NSMutableArray array];
    
    for (int i = 0; i < 6; i++) {
        ACBtn *t = [ACBtn buttonWithType:UIButtonTypeSystem];
        t.frame = CGRectMake(sixth*i, 0, sixth, tabBarH-1);
        [t setTitle:tabTitles[i] forState:UIControlStateNormal];
        [t setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        t.titleLabel.font = [UIFont boldSystemFontOfSize:9];
        t.backgroundColor = (i == 0) ? tabActiveColor() : tabInactiveColor();
        NSInteger idx = i; 
        t.action = ^(UIButton *b){ switchToTab(idx); };
        [t addTarget:t action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
        [tabBar addSubview:t]; 
        [tabBtns addObject:t];
        
        if (i > 0) {
            UIView *div = [[UIView alloc] initWithFrame:CGRectMake(sixth*i-0.5, 4, 1, tabBarH-10)];
            div.backgroundColor = [UIColor colorWithRed:1.0 green:0.20 blue:0.20 alpha:0.45]; 
            [tabBar addSubview:div];
        }
    }
    
    itemsTabBtn = tabBtns[0]; 
    mobTabBtn = tabBtns[1]; 
    cameraTabBtn = tabBtns[2];
    sceneryTabBtn = tabBtns[3]; 
    settingsTabBtn = tabBtns[4]; 
    writerTabBtn = tabBtns[5];
    
    CGFloat contentY = tabBarY + tabBarH, contentH = pH - contentY;
    
    itemsTabView = buildItemsTab(w, contentH); 
    itemsTabView.frame = CGRectMake(0, contentY, w, contentH);
    [panel addSubview:itemsTabView];
    
    mobTabView = buildMobsTab(w, contentH); 
    mobTabView.frame = CGRectMake(0, contentY, w, contentH);
    mobTabView.hidden = YES; 
    [panel addSubview:mobTabView];
    
    cameraTabView = buildCameraTab(w, contentH); 
    cameraTabView.frame = CGRectMake(0, contentY, w, contentH);
    cameraTabView.hidden = YES; 
    [panel addSubview:cameraTabView];
    
    sceneryTabView = buildSceneryTab(w, contentH); 
    sceneryTabView.frame = CGRectMake(0, contentY, w, contentH);
    sceneryTabView.hidden = YES; 
    [panel addSubview:sceneryTabView];
    
    settingsTabView = buildSettingsTab(w, contentH); 
    settingsTabView.frame = CGRectMake(0, contentY, w, contentH);
    settingsTabView.hidden = YES; 
    [panel addSubview:settingsTabView];
    
    writerTabView = buildWriterTab(w, contentH); 
    writerTabView.frame = CGRectMake(0, contentY, w, contentH);
    writerTabView.hidden = YES; 
    [panel addSubview:writerTabView];
    
    [menuWindow addSubview:panel];
}

static ACDragButton *toggleBtn;

static void createToggleButton(void) {
    CGRect scr = UIScreen.mainScreen.bounds;
    ACDragButton *btn = [ACDragButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(scr.size.width - 62, 120, 52, 52);
    btn.backgroundColor = [UIColor colorWithRed:0.40 green:0.06 blue:0.06 alpha:0.93];
    btn.layer.cornerRadius = 10; 
    btn.layer.borderWidth = 1.8;
    btn.layer.borderColor = [UIColor colorWithRed:0.90 green:0.20 blue:0.20 alpha:1].CGColor;
    [btn setTitle:@"☰" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:24];
    [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
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
                menuWindow = [[ACPassthroughWindow alloc] initWithWindowScene:(UIWindowScene*)s]; 
                break;
            }
        }
    }
    if (!menuWindow) menuWindow = [[ACPassthroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    
    menuWindow.windowLevel = UIWindowLevelAlert + 100;
    menuWindow.backgroundColor = UIColor.clearColor; 
    menuWindow.userInteractionEnabled = YES;
    menuWindow.rootViewController = [UIViewController new];
    menuWindow.rootViewController.view.backgroundColor = UIColor.clearColor;
    menuWindow.hidden = NO; 
    
    createToggleButton(); 
    createMenuPanel();
}

#pragma mark - Display Mode

static void rebuildTabsForWidth(CGFloat w, CGFloat h, CGFloat contentY) {
    // Remove old tab views
    [itemsTabView removeFromSuperview];
    [mobTabView removeFromSuperview];
    [cameraTabView removeFromSuperview];
    [sceneryTabView removeFromSuperview];
    [settingsTabView removeFromSuperview];
    [writerTabView removeFromSuperview];
    
    // Build new tab views with updated width
    itemsTabView = buildItemsTab(w, h); 
    itemsTabView.frame = CGRectMake(0, contentY, w, h);
    [menuPanel addSubview:itemsTabView];
    
    mobTabView = buildMobsTab(w, h); 
    mobTabView.frame = CGRectMake(0, contentY, w, h);
    mobTabView.hidden = YES; 
    [menuPanel addSubview:mobTabView];
    
    cameraTabView = buildCameraTab(w, h); 
    cameraTabView.frame = CGRectMake(0, contentY, w, h);
    cameraTabView.hidden = YES; 
    [menuPanel addSubview:cameraTabView];
    
    sceneryTabView = buildSceneryTab(w, h); 
    sceneryTabView.frame = CGRectMake(0, contentY, w, h);
    sceneryTabView.hidden = YES; 
    [menuPanel addSubview:sceneryTabView];
    
    settingsTabView = buildSettingsTab(w, h); 
    settingsTabView.frame = CGRectMake(0, contentY, w, h);
    settingsTabView.hidden = YES; 
    [menuPanel addSubview:settingsTabView];
    
    writerTabView = buildWriterTab(w, h); 
    writerTabView.frame = CGRectMake(0, contentY, w, h);
    writerTabView.hidden = YES; 
    [menuPanel addSubview:writerTabView];
    
    // Restore current tab
    switchToTab(_currentTabIndex);
}

static void applyDisplayMode(NSInteger mode) {
    displayMode = mode;
    if (!menuPanel || !menuWindow) return;
    
    CGRect scr = UIScreen.mainScreen.bounds;
    
    // Wider menu - iPhone: 80%, iPad: 90%
    CGFloat wPct = (mode == 1) ? 0.90f : 0.80f;
    CGFloat hPct = (mode == 1) ? 0.88f : 0.80f;
    CGFloat w  = scr.size.width  * wPct;
    CGFloat pH = scr.size.height * hPct;
    CGFloat x  = (scr.size.width  - w)  / 2.0;
    CGFloat y  = (scr.size.height - pH) / 2.0;
    
    // Calculate tab bar position (same as in createMenuPanel)
    CGFloat tabBarY = 44;
    CGFloat tabBarH = 36;
    CGFloat contentY = tabBarY + tabBarH;
    CGFloat contentH = pH - contentY;
    
    // First resize the panel
    [UIView animateWithDuration:0.25 animations:^{
        menuPanel.frame = CGRectMake(x, y, w, pH);
    } completion:^(BOOL finished) {
        // Then rebuild tabs with new width
        rebuildTabsForWidth(w, contentH, contentY);
    }];
}

static void relayoutMenuForBounds(CGRect scr) {
    if (!menuPanel || !menuWindow) return;
    
    BOOL landscape = scr.size.width > scr.size.height;
    CGFloat wPct  = landscape ? 0.70f : 0.80f;
    CGFloat hPct  = landscape ? 0.74f : 0.80f;
    CGFloat w  = scr.size.width  * wPct;
    CGFloat pH = scr.size.height * hPct;
    CGFloat x  = (scr.size.width  - w)  / 2.0;
    CGFloat y  = (scr.size.height - pH) / 2.0;
    
    menuWindow.frame = scr;
    menuPanel.frame = CGRectMake(x, y, w, pH);
    
    if (toggleBtn) {
        CGRect tf = toggleBtn.frame;
        tf.origin.x = scr.size.width - 62;
        tf.origin.y = MIN(tf.origin.y, scr.size.height - tf.size.height - 20);
        toggleBtn.frame = tf;
    }
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

    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIDeviceOrientationDidChangeNotification
                    object:nil 
                    queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *n) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
                CGRect scr = UIScreen.mainScreen.bounds;
                relayoutMenuForBounds(scr);
            });
    }];
}
