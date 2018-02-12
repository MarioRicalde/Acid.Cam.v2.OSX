//
//  AC_Controller.m
//  Acid.Cam.2
//  https://github.com/lostjared
//  Created by Jared Bruni on 6/3/13.

/*
 
 GitHub: http://github.com/lostjared
 Website: http://lostsidedead.com
 YouTube: http://youtube.com/LostSideDead
 Instagram: http://instagram.com/jaredbruni
 Twitter: http://twitter.com/jaredbruni
 Facebook: http://facebook.com/LostSideDead0x
 
 You can use this program free of charge and redistrubute as long
 as you do not charge anything for this program. This program is 100%
 Free.
 
 
 BSD 2-Clause License
 
 Copyright (c) 2018, Jared Bruni
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

//
#import "AC_Controller.h"
#include<string>
#include<dlfcn.h>
#include<unistd.h>
#include<dirent.h>
#include<time.h>
#include<vector>
#include<algorithm>

NSTextView *logView;
NSTextField *frame_count;
NSMutableArray *custom_array;
bool isPaused = false;
NSSlider *frame_slider;
NSMenuItem *stop_prog_i;
AC_Controller *controller;
pixel pix;
drawn d;
bool plugin_loaded = false;
void *library = NULL;
std::ostringstream ftext;
std::ostringstream stream;
cv::Mat blend_image;
bool blend_set = false;
int camera_mode = 0;
bool disableFilter;
cv::VideoCapture *capture;
NSThread *background;
bool camera_active = false;
cv::Mat old_frame;

const char **convertToStringArray(std::vector<std::string> &v) {
    char **arr = new char*[v.size()+2];
    for(unsigned int i = 0; i < v.size(); ++i) {
        std::string::size_type len = v[i].length();
        arr[i] = new char [len+2];
        snprintf(arr[i],len+1,"%s", v[i].c_str());
    }
    arr[v.size()] = 0;
    return (const char**)arr;
}

void eraseArray(const char **szArray, unsigned long size) {
    for(unsigned long i = 0; i < size; ++i)
        delete [] szArray[i];
    delete [] szArray;
}

NSInteger _NSRunAlertPanel(NSString *msg1, NSString *msg2, NSString *button1, NSString *button2, NSString *button3) {
    NSAlert *alert = [[NSAlert alloc] init];
    if(button1 != nil) [alert addButtonWithTitle:button1];
    if(button2 != nil) [alert addButtonWithTitle:button2];
    if(msg1 != nil) [alert setMessageText:msg1];
    if(msg2 != nil) [alert setInformativeText:msg2];
    NSInteger rt_val = [alert runModal];
    [alert release];
    return rt_val;
}

extern int program_main(std::string input_file, bool noRecord, std::string outputFileName, int capture_width, int capture_height, int capture_device, int frame_count, float pass2_alpha, std::string file_path);

void flushToLog(std::ostringstream &sout) {
    NSTextView *sv = logView;
    NSString *value = [[sv textStorage] string];
    NSString *newValue = [[NSString alloc] initWithFormat: @"%@%s", value, sout.str().c_str()];
    [sv setString: newValue];
    [sv scrollRangeToVisible:NSMakeRange([[sv string] length], 0)];
    [newValue release];
    sout.str("");
}

void setFrameLabel(std::ostringstream &text) {
    NSString *str = [NSString stringWithUTF8String: text.str().c_str()];
    [frame_count setStringValue: str];
    text.str("");
}

void setEnabledProg() {
    [stop_prog_i setEnabled: NO];
}

@implementation AC_Controller

- (void) stopCV_prog {
    [startProg setEnabled: YES];
    programRunning = false;
}


- (IBAction) quitProgram: (id) sender {
    if(programRunning == true) {
        breakProgram = true;
        //camera_active = false;
    }
    else {
        [NSApp terminate:nil];
    }
}

- (void) dealloc {
    [custom_array release];
    [self closePlugin];
    [menu_cat release];
    [menu_all release];
    [menu_cat_custom release];
    [menu_all_custom release];
    for(unsigned int i = 1; i < 10; ++i) {
        [menu_items[i] release];
        [menu_items_custom[i] release];
    }
    [super dealloc];
}

- (void) awakeFromNib {
    controller = self;
    [video_file setEnabled: NO];
    [resolution setEnabled: NO];
    [device_index setEnabled: NO];
    logView = t_view;
    frame_count = framecount;
    [window1 setLevel: NSStatusWindowLevel];
    [window2 setLevel: NSStatusWindowLevel];
    [custom_window setLevel: NSStatusWindowLevel];
    [alpha_window setLevel: NSStatusWindowLevel];
    [image_select setLevel: NSStatusWindowLevel];
    [plugin_window setLevel: NSStatusWindowLevel];
    [goto_frame setLevel: NSStatusWindowLevel];
    ac::fill_filter_map();
    [self createMenu: &menu_cat menuAll:&menu_all items:menu_items custom:NO];
    [self createMenu: &menu_cat_custom menuAll: &menu_all_custom items:menu_items_custom custom:YES];
    [categories setMenu: menu_cat];
    [categories_custom setMenu:menu_cat_custom];
    [current_filter setMenu: menu_items[0]];
    [current_filter_custom setMenu: menu_items_custom[0]];
    custom_array = [[NSMutableArray alloc] init];
    [table_view setDelegate:self];
    [table_view setDataSource:self];
    [menuPaused setEnabled: NO];
    stop_prog_i = stop_prog;
    frame_slider = goto_f;
    ftext.setf(std::ios::fixed, std::ios::floatfield);
    ftext.precision(2);
    srand((unsigned int)time(0));
    pauseStepTrue = false;
    camera_mode = 0;
}

- (void) createMenu: (NSMenu **)cat menuAll: (NSMenu **)all items: (NSMenu **)it_arr custom:(BOOL)cust {
    *cat = [[NSMenu alloc] init];
    [*cat addItemWithTitle:@"All" action:nil keyEquivalent:@""];
    [*cat addItemWithTitle:@"Blend" action:nil keyEquivalent:@""];
    [*cat addItemWithTitle:@"Distort" action:nil keyEquivalent:@""];
    [*cat addItemWithTitle:@"Pattern" action:nil keyEquivalent:@""];
    [*cat addItemWithTitle:@"Gradient" action:nil keyEquivalent:@""];
    [*cat addItemWithTitle:@"Mirror" action:nil keyEquivalent:@""];
    [*cat addItemWithTitle:@"Strobe" action:nil keyEquivalent:@""];
    [*cat addItemWithTitle:@"Blur" action:nil keyEquivalent:@""];
    [*cat addItemWithTitle:@"Image" action:nil keyEquivalent:@""];
    [*cat addItemWithTitle:@"Square" action:nil keyEquivalent:@""];
    [*cat addItemWithTitle:@"Other" action:nil keyEquivalent:@""];
    [*cat addItemWithTitle:@"Special" action:nil keyEquivalent:@""];
    
    for(unsigned int i = 1; i < 12; ++i) {
        it_arr[i] = [[NSMenu alloc] init];
    }
    
    std::vector<std::string> vzBlend { "Self AlphaBlend", "Self Scale", "Blend #3", "Negative Paradox",  "ThoughtMode", "RandTriBlend", "Filter3","Rainbow Blend","Rand Blend","Pixel Scale","Pulse", "Combine Pixels", "Blend_Angle", "XorMultiBlend", "UpDown","LeftRight", "BlendedScanLines","XorSine", "FrameBlend", "FrameBlendRGB", "PrevFrameBlend", "HorizontalBlend", "VerticalBlend", "OppositeBlend", "DiagonalLines", "HorizontalLines" };
    std::sort(vzBlend.begin(), vzBlend.end());
    const char **szBlend = convertToStringArray(vzBlend);
    
    [self fillMenuWithString: it_arr[1] stringValues:szBlend];
    eraseArray(szBlend, vzBlend.size());
    
    std::vector<std::string> svDistort { "Tri","Distort","CDraw","Sort Fuzz","Fuzz","Boxes","Boxes Fade", "ShiftPixels", "ShiftPixelsDown","WhitePixel", "Block", "BlockXor","BlockStrobe", "BlockScale", "InvertedScanlines", "ColorMorphing", "NegativeStrobe"};
    std::sort(svDistort.begin(), svDistort.end());
    const char **szDistort = convertToStringArray(svDistort);
    [self fillMenuWithString: it_arr[2] stringValues:szDistort];
    eraseArray(szDistort, svDistort.size());
    std::vector<std::string> svPattern { "Blend Fractal","Blend Fractal Mood","Diamond Pattern" };
    std::sort(svPattern.begin(), svPattern.end());
    const char **szPattern = convertToStringArray(svPattern);
    [self fillMenuWithString: it_arr[3] stringValues:szPattern];
    eraseArray(szPattern, svPattern.size());
    std::vector<std::string> svGradient { "CosSinMultiply","New Blend","Color Accumlate1", "Color Accumulate2", "Color Accumulate3", "Filter8", "Graident Rainbow","Gradient Rainbow Flash","Outward", "Outward Square","GradientLines","GradientSelf","GradientSelfVertical","GradientDown","GraidentHorizontal","GradientRGB","GradientStripes" };
    std::sort(svGradient.begin(), svGradient.end());
    const char **szGradient = convertToStringArray(svGradient);
    [self fillMenuWithString: it_arr[4] stringValues:szGradient];
    eraseArray(szGradient, svGradient.size());
    std::vector<std::string> svMirror { "NewOne", "MirrorBlend", "Sideways Mirror","Mirror No Blend","Mirror Average", "Mirror Average Mix","Reverse","Double Vision","RGB Shift","RGB Sep","Side2Side","Top2Bottom", "Soft_Mirror", "KanapaTrip"};
    std::sort(svMirror.begin(), svMirror.end());
    const char **szMirror = convertToStringArray(svMirror);
    [self fillMenuWithString: it_arr[5] stringValues:szMirror];
    eraseArray(szMirror, svMirror.size());
    std::vector<std::string> svStrobe{  "StrobeEffect", "Blank", "Type","Random Flash","Strobe Red Then Green Then Blue","Flash Black", "StrobeScan"};
    std::sort(svStrobe.begin(), svStrobe.end());
    const char **szStrobe = convertToStringArray(svStrobe);
    [self fillMenuWithString: it_arr[6] stringValues:szStrobe];
    eraseArray(szStrobe, svStrobe.size());
    std::vector<std::string> svBlur { "GaussianBlur", "Median Blur", "Blur Distortion", "ColorTrails", "TrailsFilter", "TrailsFilterIntense", "TrailsFilterSelfAlpha", "TrailsFilterXor","BlurSim" };
    std::sort(svBlur.begin(), svBlur.end());
    const char **szBlur = convertToStringArray(svBlur);
    [self fillMenuWithString: it_arr[7] stringValues:szBlur];
    eraseArray(szBlur, svBlur.size());
    std::vector<std::string> svImage{"Blend with Image", "Blend with Image #2", "Blend with Image #3", "Blend with Image #4"};
    std::sort(svImage.begin(), svImage.end());
    const char **szImage = convertToStringArray(svImage);
    [self fillMenuWithString: it_arr[8] stringValues:szImage];
    eraseArray(szImage, svImage.size());
    std::vector<std::string> svOther { "Mean", "Laplacian", "Bitwise_XOR", "Bitwise_AND", "Bitwise_OR", "Channel Sort", "Reverse_XOR", "Bitwise_Rotate", "Bitwise_Rotate Diff","Equalize","PixelSort", "GlitchSort", "HPPD", "FuzzyLines","Random Filter", "Alpha Flame Filters","Scanlines", "TV Static","FlipTrip", "Canny", "Inter","Circular","MoveRed","MoveRGB","MoveRedGreenBlue", "Wave","HighWave","VerticalSort","VerticalChannelSort","ScanSwitch","ScanAlphaSwitch", "XorAddMul", "Blend with Source", "Plugin", "Custom"};
    std::sort(svOther.begin(), svOther.end());

    const char **szOther = convertToStringArray(svOther);
    std::vector<std::string> svOther_Custom { "Mean", "Laplacian", "Bitwise_XOR", "Bitwise_AND", "Bitwise_OR", "Channel Sort", "Reverse_XOR","Bitwise_Rotate","Bitwise_Rotate Diff", "Equalize","PixelSort", "GlitchSort","HPPD","FuzzyLines","Random Filter", "Alpha Flame Filters","Scanlines", "TV Static","FlipTrip", "Canny","Inter","Circular","MoveRed","MoveRGB", "MoveRedGreenBlue", "Wave","HighWave","VerticalSort","VerticalChannelSort","ScanSwitch", "ScanAlphaSwitch","XorAddMul", "Blend with Source", "Plugin" };
    std::sort(svOther_Custom.begin(), svOther_Custom.end());
    const char **szOther_Custom = convertToStringArray(svOther_Custom);
    
    std::vector<std::string> svSquare {"SquareSwap","SquareSwap4x2","SquareSwap8x4", "SquareSwap16x8","SquareSwap64x32", "SquareBars","SquareBars8","SquareSwapRand16x8","SquareVertical8", "SquareVertical16", "SquareVertical_Roll",
        "SquareSwapSort_Roll","SquareVertical_RollReverse","SquareSwapSort_RollReverse"};
    std::sort(svSquare.begin(), svSquare.end());
    const char **szSquare = convertToStringArray(svSquare);
    [self fillMenuWithString: it_arr[9] stringValues:szSquare];
    eraseArray(szSquare, svSquare.size());

    const char *szCustom[] = {"No Filter", "Blend with Source", "Plugin", "Custom",0};
    const char *szCustom_Spec[] = {"No Filter", "Blend with Source", "Plugin",0};
    
    
    if(cust == NO) {
        [self fillMenuWithString: it_arr[10] stringValues:szOther];
        [self fillMenuWithString: it_arr[11] stringValues:szCustom];
    }
    else {
        [self fillMenuWithString: it_arr[10] stringValues:szOther_Custom];
        [self fillMenuWithString: it_arr[11] stringValues:szCustom_Spec];
    }
    
    eraseArray(szOther, svOther.size());
    eraseArray(szOther_Custom, svOther_Custom.size());
    
    *all = [[NSMenu alloc] init];
    
    for(unsigned int i = 0; i < ac::draw_max-3; ++i){
        NSString *s = [NSString stringWithUTF8String: ac::draw_strings[i].c_str()];
        if(cust == YES) {
            if(ac::draw_strings[i] != "Custom") {
                NSMenuItem *item_custom = [[NSMenuItem alloc] initWithTitle:s action:NULL keyEquivalent:@""];
                [*all addItem:item_custom];
                [item_custom release];
            }
        } else {
            NSMenuItem *item_custom = [[NSMenuItem alloc] initWithTitle:s action:NULL keyEquivalent:@""];
            [*all addItem:item_custom];
            [item_custom release];
        }
    }
    
    it_arr[0] = *all;
}

- (void) fillMenuWithString: (NSMenu *)menu stringValues:(const char **) items {
    for(unsigned int q = 0; items[q] != 0; ++q) {
        [menu addItemWithTitle: [NSString stringWithUTF8String:items[q]] action:nil keyEquivalent:@""];
    }
}


- (IBAction) menuSelected: (id) sender {
    NSInteger index = [categories indexOfSelectedItem];
    [current_filter setMenu: menu_items[index]];
}

- (IBAction) customMenuSelected:(id) sender {
    NSInteger index = [categories_custom indexOfSelectedItem];
    [current_filter_custom setMenu: menu_items_custom[index]];
}


- (IBAction) changeFilter: (id) sender {
    NSInteger current = [current_filter indexOfSelectedItem];
    NSInteger index = [categories indexOfSelectedItem];
    
    NSMenuItem *item = [menu_items[index] itemAtIndex:current];
    NSString *title = [item title];
    ac::draw_offset = ac::filter_map[[title UTF8String]];
    std::ostringstream strout;
    strout << "Filter set to: " << ac::draw_strings[ac::draw_offset] << "\n";
    flushToLog(strout);
    if(ac::draw_strings[ac::draw_offset] == "Custom") {
        [negate_checked setIntegerValue: NSOffState];
        [custom_window orderFront:self];
    }
    if(ac::draw_strings[ac::draw_offset] == "Alpha Flame Filters") {
        [alpha_window orderFront:self];
    }
    if(ac::draw_strings[ac::draw_offset] == "Plugin") {
        [plugin_window orderFront:self];
    }
    if((ac::draw_strings[ac::draw_offset] == "Blend with Image") || (ac::draw_strings[ac::draw_offset] == "Blend with Image #2") || (ac::draw_strings[ac::draw_offset] == "Blend with Image #3") || (ac::draw_strings[ac::draw_offset] == "Blend with Image #4")) {
        [image_select orderFront: self];
    }
}

- (IBAction) downloadNewestVersion: (id) sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/lostjared/Acid.Cam.v2.OSX/releases"]];
}

- (IBAction) stopProgram: (id) sender {
    stopProgram = true;
    [menuPaused setEnabled: NO];
    [menu_freeze setEnabled: NO];
    stopCV();
}

- (IBAction) selectPlugin: (id) sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    if([panel runModal]) {
        NSString *file_type = [[panel URL] path];
        [plugin_dir removeAllItems];
        [plugin_name setStringValue: file_type];
        [self loadDir:[file_type UTF8String]];
    }
}

- (IBAction) setPlugin: (id) sender {
    [self closePlugin];
    NSString *file_type = [NSString stringWithFormat: @"%@/%@", [plugin_name stringValue], [plugin_dir objectValueOfSelectedItem]];
    pix = [self loadPlugin: file_type];
    if(pix == NULL)
        plugin_loaded = false;
    else
        plugin_loaded = true;
    
    std::ostringstream plug;
    plug << "Loaded Plugin: " << [file_type UTF8String] << "\n";
    flushToLog(plug);
}

- (void) loadDir: (std::string) str {
    DIR *dir = opendir(str.c_str());
    if (dir == NULL)
    {
        std::cerr << "Error could not open directory.\n";
        return;
    }
    dirent *e;
    while ((e = readdir(dir)))
    {
        if (e->d_type == DT_REG)
        {
            std::string file = e->d_name;
            if (file.find(".dylib") != -1)
            {
                
                NSString *s = [NSString stringWithUTF8String: e->d_name];
                [plugin_dir addItemWithObjectValue: s];
                
            }
        }
    }
    closedir(dir);
}

- (pixel) loadPlugin: (NSString *)str {
    library = dlopen([str UTF8String], RTLD_LAZY);
    if(library == NULL) {
        std::cerr << "Error could not open: " << [str UTF8String] << "\n";
        _NSRunAlertPanel(@"Error Occoured Loading Plugin", @"Exiting...", @"Ok", nil, nil);
        exit(1);
    }
    void *addr;
    // load the plugin function to process pixels
    addr = dlsym(library, "pixel");
    pixel pix;
    pix = reinterpret_cast<pixel>(addr);
    const char *error;
    error = dlerror();
    if(error) {
        std::cerr << "Could not load pixel: " << error << "\n";
        _NSRunAlertPanel(@"Could not load Plugin", @"Error loading plugin", @"Ok", nil,nil);
        return NULL;
    }
    addr = dlsym(library,"drawn");
    d = reinterpret_cast<drawn>(addr);
    error = dlerror();
    if(error) {
        std::cerr << "Could not load pixel: " << error << "\n";
        _NSRunAlertPanel(@"Could not load Plugin", @"Error loading plugin", @"Ok", nil,nil);
        return NULL;
    }
    return pix;
}

- (void) closePlugin {
    if(library != NULL)
        dlclose(library);
}

-(IBAction) startProgram: (id) sender {
    std::string input_file;
    if([videoFileInput state] == NSOnState) {
        input_file = [[video_file stringValue] UTF8String];
        if(input_file.length() == 0) {
            _NSRunAlertPanel(@"No Input file selected\n", @"No Input Selected", @"Ok", nil, nil);
            return;
        }
        camera_mode = 1;
    } else camera_mode = 0;
    NSInteger res = [resolution indexOfSelectedItem];
    int res_x[3] = { 640, 1280, 1920 };
    int res_y[3] = { 480, 720, 1080 };
    bool r;
    if([record_op integerValue] == 1)
        r = false;
    else
        r = true;
    freeze_count = 0;
    NSInteger checkedState = [menuPaused state];
    isPaused = (checkedState == NSOnState) ? true : false;
    static unsigned int counter = 0;
    std::ostringstream fname_stream;
    std::string filename;
    NSInteger popupType = [output_Type indexOfSelectedItem];
    if(!r) {
        ++counter;
    }
    time_t t = time(0);
    struct tm *m;
    m = localtime(&t);
    std::ostringstream time_stream;
    time_stream << "-" << (m->tm_year + 1900) << "." << (m->tm_mon + 1) << "." << m->tm_mday << "_" << m->tm_hour << "." << m->tm_min << "." << m->tm_sec <<  "_";
    if(popupType == 0)
        fname_stream << time_stream.str() << "AC2.Output." << (counter) << ".mov";
    else
        fname_stream << time_stream.str() << "AC2.Output." << (counter) << ".avi";
    filename = fname_stream.str();
    NSArray* paths = NSSearchPathForDirectoriesInDomains( NSMoviesDirectory, NSUserDomainMask, YES );
    std::string add_path = std::string([[paths objectAtIndex: 0] UTF8String])+std::string("/")+[[prefix_input stringValue] UTF8String];
    std::cout << add_path << "\n";
    [startProg setEnabled: NO];
    [menuPaused setEnabled: YES];
    if(camera_mode == 1) {
        renderTimer = [NSTimer timerWithTimeInterval:0.001   //a 1ms time interval
                                              target:self
                                            selector:@selector(cvProc:)
                                            userInfo:nil
                                             repeats:YES];
    } else {
        renderTimer = [NSTimer timerWithTimeInterval: 0.001 target:self selector:@selector(camProc:) userInfo:nil repeats:YES];
    }
    if(camera_mode == 1)
        capture = capture_video.get();
    else
        capture = capture_camera.get();
    int ret_val = program_main((int)popupType, input_file, r, filename, res_x[res], res_y[res],(int)[device_index indexOfSelectedItem], 0, 0.75f, add_path);
    if(ret_val != 0) {
        _NSRunAlertPanel(@"Failed to initalize camera\n", @"Camera Init Failed\n", @"Ok", nil, nil);
        std::cout << "DeviceIndex: " << (int)[device_index indexOfSelectedItem] << " input file: " << input_file << " filename: " << filename << " res: " << res_x[res] << "x" << res_y[res] << "\n";
        programRunning = false;
        [startProg setEnabled: YES];
        [window1 orderOut:self];
    } else {
        if([menu_freeze state] == NSOnState) {
            capture->read(old_frame);
            ++frame_cnt;
        }
        if(camera_mode == 0) {
            frames_captured = 0;
            background = [[NSThread alloc] initWithTarget:self selector:@selector(camThread:) object:nil];
            [background start];
            camera_active = true;
        }
        [window1 orderFront:self];
    }
}

- (void) stopCamera {
    camera_active = false;
    [finish_queue orderFront:self];
    [finish_queue_progress startAnimation:self];
    if(renderTimer != nil && renderTimer.valid) {
        [renderTimer invalidate];
        renderTimer = nil;
    }
}

- (void) camProc: (id) sender {
    if(breakProgram == true || stopProgram == true) {
        [self stopCamera];
        return;
    }
    if(isPaused && pauseStepTrue == true) {
        pauseStepTrue = false;
    }
    else if(isPaused) return;
    if(capture_camera->isOpened() && camera_active == true) {
        if([menu_freeze state] == NSOffState) {
            capture_camera->grab();
            frames_captured++;
        }
    }
}

- (void) camThread: (id) sender {
    cv::Mat frame;
    bool got_frame = true;
    while(camera_active && got_frame) {
        if(isPaused) continue;
        cv::Mat temp_frame;
        if([menu_freeze state] == NSOffState) {
            got_frame = capture->retrieve(frame);
            old_frame = frame.clone();
        } else {
            frame = old_frame.clone();
        }
        
        if([rotate_v state] == NSOnState) {
            cv::flip(frame, temp_frame, 1);
            frame = temp_frame;
        }
        if([rotate_h state] == NSOnState) {
            cv::flip(frame, temp_frame, 0);
            frame = temp_frame;
        }
        ++frame_cnt;
        if((ac::draw_strings[ac::draw_offset] == "Blend with Source") || (ac::draw_strings[ac::draw_offset] == "Custom")) {
            ac::orig_frame = frame.clone();
        }
        dispatch_sync(dispatch_get_main_queue(), ^{
            if(ac::draw_strings[ac::draw_offset] != "Custom") {
                if([negate_checked integerValue] == NSOffState) ac::isNegative = false;
                else ac::isNegative = true;
                ac::color_order = (int) [corder indexOfSelectedItem];
            }
        });
        if(disableFilter == false) ac::draw_func[ac::draw_offset](frame);
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            if([corder indexOfSelectedItem] == 5) {
                cv::Mat change;
                cv::cvtColor(frame, change, cv::COLOR_BGR2GRAY);
                cv::cvtColor(change, frame, cv::COLOR_GRAY2BGR);
            }
            cv::imshow("Acid Cam v2", frame);
            ftext << "(Frames/Total Frames/Seconds/MB): " << frame_cnt << "/" << "0" << "/" << (frame_cnt/ac::fps) << "/" << ((file_size/1024)/1024) << " MB";
            if(camera_mode == 1) {
                float val = frame_cnt;
                float size = total_frames;
                if(size != 0)
                    ftext << " - " << (val/size)*100 << "% ";
            }
            setFrameLabel(ftext);
        });
        if(ac::noRecord == false) {
            if(writer->isOpened()) writer->write(frame);
            if(file.is_open()) {
                file.seekg(0, std::ios::end);
                file_size = file.tellg();
            }
        }
        if(ac::snapShot == true) {
            static unsigned int index = 0;
            stream.str("");
            time_t t = time(0);
            struct tm *m;
            m = localtime(&t);
            stream << add_path << "-" << (m->tm_year + 1900) << "." << (m->tm_mon + 1) << "." << m->tm_mday << "_" << m->tm_hour << "." << m->tm_min << "." << m->tm_sec <<  "_" << (++index) << ".Acid.Cam.Image." << ac::draw_strings[ac::draw_offset] << ((ac::snapshot_Type == 0) ? ".jpg" : ".png");
            imwrite(stream.str(), frame);
            sout << "Took snapshot: " << stream.str() << "\n";
            ac::snapShot = false;
            // flush to log
            dispatch_sync(dispatch_get_main_queue(), ^{
                flushToLog(sout);
            });
        }
    }
    dispatch_sync(dispatch_get_main_queue(), ^{
        [finish_queue orderOut:self];
        cv::destroyWindow("Acid Cam v2");
        cv::destroyWindow("Controls");
        if(!ac::noRecord && writer->isOpened()) {
            sout << "Wrote to Video File: " << ac::fileName << "\n";
            writer->release();
        }
        sout << (video_total_frames+frame_cnt) << " Total frames\n";
        sout << ((video_total_frames+frame_cnt)/ac::fps) << " Seconds\n";
        file.close();
        flushToLog(sout);
        setEnabledProg();
        if(breakProgram == true) {
            [NSApp terminate:nil];
        }
        programRunning = false;
        [startProg setEnabled: YES];
        [background release];
        camera_active = false;
    });
}

- (void) cvProc: (id) sender {
    if(breakProgram == true || stopProgram == true) { stopCV(); return; }
    if(isPaused && pauseStepTrue == true) {
        pauseStepTrue = false;
    }
    else if(isPaused) return;
    cv::Mat frame;
    bool frame_read = true;
    if([menu_freeze state] == NSOffState) {
        frame_read = capture->read(frame);
        old_frame = frame.clone();
    } else {
        frame = old_frame.clone();
    }
    if(capture->isOpened() && frame_read == false) {
        ++frame_cnt;
        ftext  << "(Frames/Total Frames/Seconds/MB): " << frame_cnt << "/" << total_frames << "/" << ((freeze_count+video_total_frames+frame_cnt)/ac::fps) << "/" << ((file_size/1024)/1024) << " MB";
        if(ac::noRecord == false) {
            if(file.is_open()) {
                file.seekg(0, std::ios::end);
                file_size = file.tellg();
            }
        }
        if(camera_mode == 1) {
            // float val = frame_cnt;
            float size = total_frames;
            if(size != 0)
                ftext << " - 100% ";
        }
        setFrameLabel(ftext);
        if([chk_repeat integerValue] != 0) {
            video_total_frames += frame_cnt;
            jumptoFrame(0);
            return;
        }
        stopCV();
        return;
    }
    cv::Mat temp_frame;
    if([rotate_v state] == NSOnState) {
        cv::flip(frame, temp_frame, 1);
        frame = temp_frame;
    }
    if([rotate_h state] == NSOnState) {
        cv::flip(frame, temp_frame, 0);
        frame = temp_frame;
    }
    if((ac::draw_strings[ac::draw_offset] == "Blend with Source") || (ac::draw_strings[ac::draw_offset] == "Custom")) {
        ac::orig_frame = frame.clone();
    }
    if(ac::draw_strings[ac::draw_offset] != "Custom") {
        if([negate_checked integerValue] == NSOffState) ac::isNegative = false;
        else ac::isNegative = true;
        ac::color_order = (int) [corder indexOfSelectedItem];
    }
    if(disableFilter == false) ac::draw_func[ac::draw_offset](frame);
    if([menu_freeze state] == NSOffState)
        ++frame_cnt;
    else
        ++freeze_count;
    if([corder indexOfSelectedItem] == 5) {
        cv::Mat change;
        cv::cvtColor(frame, change, cv::COLOR_BGR2GRAY);
        cv::cvtColor(change, frame, cv::COLOR_GRAY2BGR);
    }
    cv::imshow("Acid Cam v2", frame);
    ftext << "(Frames/Total Frames/Seconds/MB): " << frame_cnt << "/" << total_frames << "/" << ((freeze_count+video_total_frames+frame_cnt)/ac::fps) << "/" << ((file_size/1024)/1024) << " MB";
    if(camera_mode == 1) {
        float val = frame_cnt;
        float size = total_frames;
        if(size != 0)
            ftext << " - " << (val/size)*100 << "% ";
    }
    setFrameLabel(ftext);
    if(ac::noRecord == false) {
        if(writer->isOpened() )writer->write(frame);
        if(file.is_open()) {
            file.seekg(0, std::ios::end);
            file_size = file.tellg();
        }
    }
    if(ac::snapShot == true) {
        static unsigned int index = 0;
        stream.str("");
        time_t t = time(0);
        struct tm *m;
        m = localtime(&t);
        stream << add_path << "-" << (m->tm_year + 1900) << "." << (m->tm_mon + 1) << "." << m->tm_mday << "_" << m->tm_hour << "." << m->tm_min << "." << m->tm_sec <<  "_" << (++index) << ".Acid.Cam.Image." << ac::draw_strings[ac::draw_offset] << ((ac::snapshot_Type == 0) ? ".jpg" : ".png");
        imwrite(stream.str(), frame);
        sout << "Took snapshot: " << stream.str() << "\n";
        ac::snapShot = false;
        // flush to log
        flushToLog(sout);
    }
}

- (IBAction) openWebcamDialog: (id) sender {
    if([startaction indexOfSelectedItem] == 0)
        [window1 orderFront: self];
    else { // load video
        [window2 orderFront: self];
    }
}

- (IBAction) startVideoProgram: (id) sender {}

- (IBAction) selectFile: (id) sender {
    NSOpenPanel *pan = [NSOpenPanel openPanel];
    [pan setAllowsMultipleSelection: NO];
    NSArray *ar = [NSArray arrayWithObjects: @"mov", @"avi", @"mp4", @"mkv",@"m4v", nil];
    [pan setAllowedFileTypes:ar];
    if([pan runModal]) {
        NSString *file_name = [[pan URL] path];
        if(file_name != 0) {
            [video_file setStringValue: file_name];
        }
    }
}

- (IBAction) setRotate_V:(id) sender {
    NSInteger state = [rotate_v state];
    if(state == NSOffState) {
        [rotate_v setState:NSOnState];
    } else {
        [rotate_v setState:NSOffState];
    }
    
}
- (IBAction) setRotate_H:(id) sender {
    NSInteger state = [rotate_h state];
    if(state == NSOffState) {
        [rotate_h setState:NSOnState];
    } else {
        [rotate_h setState:NSOffState];
    }
}

- (IBAction) takeSnopshot: (id) sender {
    ac::snapShot = true;
    ac::snapshot_Type = 0;
}

- (IBAction) takeSnapshotPNG: (id) sender {
    ac::snapShot = true;
    ac::snapshot_Type = 1;
}

- (IBAction) checkChanged: (id) sender {
    if([videoFileInput integerValue] == 0 ) {
        [video_file setEnabled: NO];
        [resolution setEnabled: YES];
        [device_index setEnabled: YES];
        [selectVideoFile setEnabled: NO];
        [chk_repeat setEnabled:NO];
    }
    else {
        [video_file setEnabled: NO];
        [resolution setEnabled: NO];
        [device_index setEnabled: NO];
        [selectVideoFile setEnabled: YES];
        [chk_repeat setEnabled:YES];
    }
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    NSString *str =  [[aTableColumn headerCell] stringValue];
    NSNumber *number = [custom_array objectAtIndex:rowIndex];
    if( [str isEqualTo:@"Filter"] ) {
        int value = (int)[number integerValue];
        NSString *s = [NSString stringWithFormat:@"%s", ac::draw_strings[value].c_str()];
        //        [number release];
        return s;
    }
    else {
        NSString *s = [NSString stringWithFormat: @"%d", (int)[number integerValue]];
        //        [number release];
        return s;
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [custom_array count];
}

- (IBAction) addCustomItem: (id) sender {
    
    NSInteger index = [current_filter_custom indexOfSelectedItem];
    NSInteger cate = [categories_custom indexOfSelectedItem];
    NSMenuItem *item = [menu_items_custom[cate] itemAtIndex: index];
    NSString *title = [item title];
    
    if(index >= 0 && cate >= 0) {

        int filter_value = ac::filter_map[[title UTF8String]];
        [custom_array addObject: [NSNumber numberWithInt: filter_value]];
        [table_view reloadData];
        
    }
}

- (IBAction) removeCustomItem: (id) sender {
    NSInteger index = [table_view selectedRow];
    if(index >= 0) {
        [custom_array removeObjectAtIndex:index];
        [table_view reloadData];
    }
}

- (IBAction) moveCustomUp: (id) sender {
    NSInteger index = [table_view selectedRow];
    if(index > 0) {
        NSInteger pos = index-1;
        id obj = [custom_array objectAtIndex:pos];
        id mv = [custom_array objectAtIndex:index];
        [custom_array setObject:obj atIndexedSubscript:index];
        [custom_array setObject:mv atIndexedSubscript: pos];
        [table_view deselectAll:self];
        [table_view reloadData];
    }
}
- (IBAction) moveCustomDown: (id) sender {
    NSInteger index = [table_view selectedRow];
    if(index < [custom_array count]-1) {
        NSInteger pos = index+1;
        id obj = [custom_array objectAtIndex:pos];
        id mv = [custom_array objectAtIndex:index];
        [custom_array setObject:obj atIndexedSubscript:index];
        [custom_array setObject:mv atIndexedSubscript: pos];
        [table_view deselectAll:self];
        [table_view reloadData];
    }
}

- (IBAction) stepPause: (id) sender {
    pauseStepTrue = true;
    std::ostringstream stream;
    stream << "Stepped to next frame.\n";
    flushToLog(stream);
}

- (IBAction) selectFileForPrefix: (id) sender {
    NSSavePanel *panel = [NSSavePanel savePanel];
    if([panel runModal]) {
        [prefix_input setStringValue:[[panel URL] path]];
    }
}

- (IBAction) changeOrder: (id) sender {
    ac::color_order = (int) [corder indexOfSelectedItem];
}

- (IBAction) pauseProgram: (id) sender {
    NSInteger checkedState = [menuPaused state];
    std::ostringstream stream;
    if(checkedState == NSOnState) {
        [menuPaused setState: NSOffState];
        [pause_step setEnabled: NO];
        isPaused = false;
        stream << "Program unpaused.\n";
        flushToLog(stream);
        
    } else {
        [menuPaused setState: NSOnState];
        isPaused = true;
        [pause_step setEnabled: YES];
        stream << "Program paused.\n";
        flushToLog(stream);
    }
}

- (IBAction) disableFilters: (id) sender {
    NSInteger checkedState = [disable_filters state];
    std::ostringstream stream;
    if(checkedState == NSOnState) {
        [disable_filters setState: NSOffState];
        // enable
        disableFilter = false;
        stream << "Filters enabled.\n";
        flushToLog(stream);
        
    } else {
        [disable_filters setState: NSOnState];
        // disable
        disableFilter = true;
        stream << "Filters disabled.\n";
        flushToLog(stream);
    }
}

- (IBAction) goto_Frame: (id) sender {
    int val = (int)[frame_slider integerValue];
    jumptoFrame(val);
    std::ostringstream stream;
    stream << "Jumped to frame: " << val << "\n";
    flushToLog(stream);
}

- (IBAction) setGoto: (id) sender {
    NSInteger time_val = [frame_slider integerValue];
    NSString *str_val = [NSString stringWithFormat:@"Jump to Time: %f Seconds Frame #%d", time_val/ac::fps, (int)time_val];
    [goto_fr setStringValue: str_val];
}

- (IBAction) openGoto: (id) sender {
    if(total_frames != 0) {
        [goto_frame orderFront:self];
    } else {
        _NSRunAlertPanel(@"Cannot jump to frame must be in video mode", @"Recording Error", @"Ok", nil, nil);
    }
}

- (IBAction) pauseVideo: (id) sender {}

- (IBAction) changeFilterIndex: (id) sender {
    current_filterx = (int) [filter_selector indexOfSelectedItem];
}

- (IBAction) changeRGB: (id) sender {
    red = (int) [slider_red integerValue];
    green = (int) [slider_green integerValue];
    blue = (int) [slider_blue integerValue];
    [slider_red_pos setIntegerValue: red];
    [slider_green_pos setIntegerValue: green];
    [slider_blue_pos setIntegerValue: blue];
}

- (IBAction) changeReverse:(id)sender {
    reverse = (int)[rgb_box indexOfSelectedItem];
}

- (IBAction) changeNegate: (id) sender {
    negate = [check_box state] == NSOffState ? false : true;
}

- (IBAction) setNegative: (id) sender {
    NSInteger chkvalue = [negate_checked integerValue];
    if(chkvalue == NSOnState) ac::isNegative = true;
    else ac::isNegative = false;
}

- (IBAction) selectImage: (id) sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:NO];
    [panel setCanChooseFiles: YES];
    [panel setAllowedFileTypes: [NSArray arrayWithObjects: @"jpg", @"png", nil]];
    if([panel runModal]) {
        NSString *file_name = [[panel URL] path];
        [image_combo addItemWithObjectValue: file_name];
    }
}
- (IBAction) setAsImage: (id) sender {
    if([image_combo indexOfSelectedItem] >= 0) {
        NSString *current = [image_combo itemObjectValueAtIndex: [image_combo indexOfSelectedItem]];
        blend_image = cv::imread([current UTF8String]);
        blend_set = true;
        std::ostringstream stream;
        stream << "Image set to: " << [current UTF8String] << "\n";
        NSString *s = [NSString stringWithFormat:@"%s", stream.str().c_str(), nil];
        _NSRunAlertPanel(@"Image set", s, @"Ok", nil, nil);
        flushToLog(stream);
    }
}

- (IBAction) showCustom: (id) sender {
    [custom_window orderFront: self];
}

- (IBAction) showActivityLog: (id) sender {
    [window1 orderFront: self];
}

- (IBAction) showSelectImage: (id) sender {
    [image_select orderFront: self];
}

- (IBAction) showAlpha: (id) sender {
    [alpha_window orderFront: self];
}

- (IBAction) showPlugins: (id) sender {
    [plugin_window orderFront:self];
}

- (IBAction) setRGB_Values: (id) sender {
    NSInteger red_val = [red_slider integerValue];
    NSInteger green_val = [green_slider integerValue];
    NSInteger blue_val = [blue_slider integerValue];
    ac::swapColor_r = (unsigned int)red_val;
    ac::swapColor_g = (unsigned int)green_val;
    ac::swapColor_b = (unsigned int)blue_val;
    [t_red setIntegerValue: red_val];
    [t_green setIntegerValue: green_val];
    [t_blue setIntegerValue: blue_val];
}

- (IBAction) menuFreeze: (id) sender {
    if([menu_freeze state] == NSOnState) {
        [menu_freeze setState: NSOffState];
    } else {
        [menu_freeze setState: NSOnState];
    }
}

@end

void custom_filter(cv::Mat &frame) {
    ac::in_custom = true;
    for(NSInteger i = 0; i < [custom_array count]; ++i) {
        if(i == [custom_array count]-1)
            ac::in_custom = false;
        
        NSNumber *num;
        @try {
            num = [custom_array objectAtIndex:i];
            NSInteger index = [num integerValue];
            ac::draw_func[(int)index](frame);
        } @catch(NSException *e) {
            NSLog(@"%@\n", [e reason]);
        }
    }
    ac::in_custom = false;
}

void setSliders(int frame_count) {
    [frame_slider setMinValue: 0];
    [frame_slider setMaxValue: frame_count];
}

void ac::plugin(cv::Mat &frame) {
    if(plugin_loaded == false) return;
    int i = 0, z = 0;
    for(z = 0; z < frame.cols; ++z) {
        for(i = 0; i < frame.rows; ++i) {
            cv::Vec3b &buffer = frame.at<cv::Vec3b>(i, z);
            unsigned char pixels[] = { buffer[0], buffer[1], buffer[2] };
            (*pix)(z, i, pixels);
            buffer[0] = pixels[0];
            buffer[1] = pixels[1];
            buffer[2] = pixels[2];
        }
    }
    (*d)();
}
