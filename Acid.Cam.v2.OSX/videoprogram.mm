/*
 * Acid Cam v2 - OpenCV Edition
 * written by Jared Bruni ( http://lostsidedead.com / https://github.com/lostjared )
 
 This software is dedicated to all the people that struggle with mental illness.
 
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

// This file contains the functions to Start/Stop the capture/recording devices
#import"AC_Controller.h"
#include<fstream>
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#undef check
#include"videocapture.h"

// Variable definiton
unsigned int int_Seed = (unsigned int)(time(0));
bool breakProgram = false, programRunning = false, stopProgram = false;
unsigned long total_frames = 0;
void ProcFrame(cv::Mat &frame);
std::unique_ptr<cv::VideoCapture> capture_camera(new cv::VideoCapture());
std::unique_ptr<cv::VideoCapture> capture_video(new cv::VideoCapture());
long frame_cnt, key;
long video_total_frames = 0;
NSTimer *renderTimer;
std::ostringstream sout;
std::unique_ptr<cv::VideoWriter> writer;
unsigned long file_size;
std::string add_path;
std::string input_name = "";

// Stop the OpenCV capture
void stopCV() {
    if(camera_active == true) {
        camera_active = false;
        return;
    }
    // if timer is valid
    if(renderTimer != nil && renderTimer.valid) {
        // stop timer
        [renderTimer invalidate];
        renderTimer = nil;
        // destroy the OpenCV Windows
        cv::destroyWindow("Acid Cam v2");
        cv::destroyWindow("Controls");
        // if recording clean up and release the writer
        if(!ac::noRecord && writer->isOpened()) {
            sout << "Wrote to Video File: " << ac::fileName << "\n";
            writer->release();
        }
        sout << frame_proc << " Total frames\n";
        sout << (frame_proc/ac::fps) << " Seconds\n";
        // flush to log
        flushToLog(sout);
        setEnabledProg();
        capture->release();
        [controller stopCV_prog];
        if(breakProgram == true) {
            [NSApp terminate:nil];
        }
    }
}


// program function to start process
int program_main(bool fps_on, double fps_val, bool u4k, int outputType, std::string input_file, bool noRecord, std::string outputFileName, int capture_width, int capture_height, int capture_device, long frame_countx, float pass2_alpha, std::string file_path) {
    programRunning = true;
    sout << "Acid Cam v" << ac::version << " Initialized ..\n" << ac::draw_max-4 << " Filters Loaded...\n";
    add_path="default";
    input_name = input_file;
    srand(static_cast<unsigned int>(time(0)));
    ac::translation_variable = 0.01;
    ac::tr = ac::translation_variable;
    ac::fileName = file_path+outputFileName;
    ac::noRecord = noRecord;
    ac::pass2_alpha = pass2_alpha;
    unsigned int seed = int_Seed;
    srand(seed);
    add_path = file_path;
    stopProgram = false;
    ac::tr =  0.3;
    ac::fps = 29.97;
    file_size = 0;
    video_total_frames = 0;
    writer.reset(new cv::VideoWriter());
    try {
        // open either camera or video file
        if(camera_mode == 0 /*&& capture->isOpened() == false*/) capture->open(capture_device);
        else if(camera_mode == 1)  {
            capture->open(input_file);
            total_frames = capture->get(CV_CAP_PROP_FRAME_COUNT);
        }
        // check that it is opened
        if (!capture->isOpened()) {
            std::cerr << "Error could not open Camera device..\n";
            return -1;
        } else
            sout << "Acid Cam Capture device [" << ((camera_mode == 0) ? "Camera" : "Video") << "] opened..\n";
        int aw = capture->get(CV_CAP_PROP_FRAME_WIDTH);
        int ah = capture->get(CV_CAP_PROP_FRAME_HEIGHT);
        if(u4k && aw != 3840 && ah != 2160)
            sout << "Resolution Upscaled to 3840x2160\n";
        else
        	sout << "Resolution: " << aw << "x" << ah << "\n";
        
        ac::fps = capture->get(CV_CAP_PROP_FPS);
        if(ac::fps_force == false && input_file.size() != 0) ac::fps = capture->get(CV_CAP_PROP_FPS);
        if(ac::fps <= 0 || ac::fps > 60) ac::fps = 30;
        sout << "FPS: " << ac::fps << "\n";
        cv::Mat frame;
        capture->read(frame);
        cv::Size frameSize = frame.size();
        ac::resolution = frame.size();
        if(camera_mode == 0 && capture_width != 0 && capture_height != 0) {
            capture->set(CV_CAP_PROP_FRAME_WIDTH, capture_width);
            capture->set(CV_CAP_PROP_FRAME_HEIGHT, capture_height);
            if(u4k)
                sout << "Resolution upsacled to  3840x2160\n";
            else
            sout << "Resolution set to " << capture_width << "x" << capture_height << "\n";
            frameSize = cv::Size(capture_width, capture_height);
        }
        setSliders(total_frames);
        bool opened = false;
        // if recording open the writer object with desired codec
        if(ac::noRecord == false) {
            cv::Size s4k = cv::Size(3840, 2160);
            if(u4k ==false) {
                s4k = frameSize;
            }
            if(camera_mode == 0 && fps_on == true) {
                ac::fps = fps_val;
            	sout << "Forced Frame Rate: " << fps_val << "\n";
            }
            if(outputType == 0)
                opened = writer->open(ac::fileName, CV_FOURCC('m','p','4','v'),  ac::fps, s4k, true);
            else
                opened = writer->open(ac::fileName, CV_FOURCC('X','V','I','D'),  ac::fps, s4k, true);
            // if writer is not opened exit
            if(writer->isOpened() == false || opened == false) {
                sout << "Error video file could not be created.\n";
                _NSRunAlertPanel(@"Error", @"Video file could not be created Output direcotry exisit?\n", @"Close", nil, nil);
                return -1;
            }
            cv::Mat outframe;
            cv::resize(frame, outframe, frameSize);
            frame = outframe;
            if(blend_image.empty())
                blend_image = frame.clone();
        }
        // output wehther recording or not
        if(ac::noRecord == false)
            sout << "Now recording .. format " << ((outputType == 0) ? "MPEG-4 (Quicktime)" : "XvID") << " \n";
        else
            sout << "Recording disabled ..\n";
        
        // create the window and show initial frame
        cv::namedWindow("Acid Cam v2",cv::WINDOW_NORMAL | cv::WINDOW_KEEPRATIO);
        cv::resizeWindow("Acid Cam v2", frameSize.width, frameSize.height);
        cv::imshow("Acid Cam v2", frame);
        // if video file go back to start
        if(camera_mode == 0) jumptoFrame(0);
        // grab the screen info
        NSRect screen = [[NSScreen mainScreen] frame];
        if(frameSize.width > screen.size.width && frameSize.height > screen.size.height) {
            rc.size.width = screen.size.width;
            rc.size.height = screen.size.height;
            resize_value = true;
            cv::resizeWindow("Acid Cam v2", rc.size.width, rc.size.height);
            
        } else {
            rc.size.width = (double) frameSize.width;
            rc.size.height = (double) frameSize.height;
        }
        // flush to log
        flushToLog(sout);
        frame_cnt = 0;
        frame_proc = 0;
        [[NSRunLoop currentRunLoop] addTimer:renderTimer
                                     forMode:NSEventTrackingRunLoopMode];
        
        [[NSRunLoop currentRunLoop] addTimer:renderTimer
                                     forMode:NSDefaultRunLoopMode];
        return 0;
    }
    // standard exceptions handled here
    catch(std::exception &e) {
        std::cerr << e.what() << " was thrown!\n";
    }
    // unknown exceptions handled here
    catch(...) {
        std::cerr << "Unknown error thrown.\n";
    }
    return 0;
}
// string stream for output
std::ostringstream strout;
// jump to frame in video
void jumptoFrame(long frame) {
    capture->set(CV_CAP_PROP_POS_FRAMES,frame);
    cv::Mat pos;
    capture->read(pos);
    capture->set(CV_CAP_PROP_POS_FRAMES,frame);
    cv::imshow("Acid Cam v2", pos);
    frame_cnt = frame;
}
