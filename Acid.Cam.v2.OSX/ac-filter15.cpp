/*
 * Software written by Jared Bruni https://github.com/lostjared
 
 This software is dedicated to all the people that experience mental illness.
 
 Website: http://lostsidedead.com
 YouTube: http://youtube.com/LostSideDead
 Instagram: http://instagram.com/jaredbruni
 Twitter: http://twitter.com/jaredbruni
 Facebook: http://facebook.com/LostSideDead0x
 
 You can use this program free of charge and redistrubute it online as long
 as you do not charge anything for this program. This program is meant to be
 100% free.
 
 BSD 2-Clause License
 
 Copyright (c) 2019, Jared Bruni
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

#include "ac.h"

void ac::ImageXorScale(cv::Mat &frame) {
    if(blend_set == false)
        return;
    cv::Mat reimage;
    cv::resize(blend_image, reimage, frame.size());
    static int scale = rand()%255;
    static int dir = rand()%2;
    for(int z = 0; z < frame.rows; ++z) {
        for(int i = 0; i < frame.cols; ++i) {
            cv::Vec3b &pixel = frame.at<cv::Vec3b>(z, i);
            cv::Vec3b copy_pix = reimage.at<cv::Vec3b>(z, i);
            for(int j = 0; j < 3; ++j) {
                pixel[j] = pixel[j]^copy_pix[j]^scale;
            }
        }
    }
    if(dir == 1) {
        ++scale;
        if(scale >= 255)
            dir = 0;
    } else {
        --scale;
        if(scale <= 1)
            dir = 1;
    }
    AddInvert(frame);
}

void ac::MatrixCollectionShiftSubFilter(cv::Mat &frame) {
    if(subfilter == -1 || ac::draw_strings[subfilter] == "MatrixCollectionShiftSubFilter")
        return;
    static MatrixCollection<32> collection;
    cv::Mat copy1 = frame.clone();
    CallFilter(subfilter, copy1);
    Smooth(copy1, &collection);
    cv::Mat copy2 = frame.clone();
    AlphaBlend(copy1, copy2, frame, 0.5);
    MedianBlend(frame);
    AddInvert(frame);
}

void ac::MatrixCollectionImageShiftSubFilter(cv::Mat &frame) {
    if(blend_set == false || subfilter == -1 || ac::draw_strings[subfilter] == "MatrixCollectionImageShiftSubFilter")
        return;
    cv::Mat reimage, copy1 = frame.clone();
    cv::resize(blend_image, reimage, frame.size());
    CallFilter(subfilter, reimage);
    static MatrixCollection<32> collection;
    Smooth(reimage, &collection);
    AlphaBlend(reimage, copy1, frame, 0.5);
    MedianBlend(frame);
    AddInvert(frame);
}

void ac::MatrixCollectionSmoothAlphaBlend(cv::Mat &frame) {
    static MatrixCollection<32> collection;
    cv::Mat copy1 = frame.clone(), copy2 = frame.clone();
    Smooth(copy1, &collection);
    AlphaBlend(copy1, copy2, frame, 0.5);
    AddInvert(frame);
}

void ac::MatrixCollectionBlurImageXorAlpha(cv::Mat &frame) {
    if(blend_set == false)
        return;
    static MatrixCollection<8> collection;
    static MatrixCollection<8> image_collection;
    cv::Mat copy1 = frame.clone(), copy2;
    cv::resize(blend_image, copy2, frame.size());
    XorAlpha(copy2);
    Smooth(copy2, &image_collection);
    Smooth(copy1, &collection);
    AlphaBlend(copy1, copy2, frame, 0.5);
    AddInvert(frame);
}

void ac::MatrixCollectionBlurImageSubFilter(cv::Mat &frame) {
    if(blend_set == false || subfilter == -1 || ac::draw_strings[subfilter] == "MatrixCollectionBlurImageSubFilter")
        return;
    static MatrixCollection<8> collection;
    static MatrixCollection<8> image_collection;
    cv::Mat copy1 = frame.clone(), copy2;
    cv::resize(blend_image, copy2, frame.size());
    CallFilter(subfilter, copy2);
    Smooth(copy2, &image_collection);
    Smooth(copy1, &collection);
    AlphaBlend(copy1, copy2, frame, 0.5);
    AddInvert(frame);
}

void ac::MatrixCollectionBlurImageSubFilter16(cv::Mat &frame) {
    if(blend_set == false || subfilter == -1 || ac::draw_strings[subfilter] == "MatrixCollectionBlurImageSubFilter16")
        return;
    static MatrixCollection<16> collection;
    static MatrixCollection<16> image_collection;
    cv::Mat copy1 = frame.clone(), copy2;
    cv::resize(blend_image, copy2, frame.size());
    CallFilter(subfilter, copy2);
    Smooth(copy2, &image_collection);
    Smooth(copy1, &collection);
    AlphaBlend(copy1, copy2, frame, 0.5);
    AddInvert(frame);
}

void ac::ImageAlphaBlendSubFilter(cv::Mat &frame) {
    if(blend_set == false || subfilter == -1 || ac::draw_strings[subfilter] == "ImageAlphaBlendSubFilter")
        return;
    static double alpha = 1.0, alpha_max = 4.0;
    cv::Mat reimage;
    cv::resize(blend_image, reimage, frame.size());
    CallFilter(subfilter, reimage);
    cv::Mat copy1 = frame.clone();
    AlphaBlend(copy1, reimage, frame, alpha);
    static int dir = 1;
    procPos(dir, alpha, alpha_max, 4.1, 0.01);
    AddInvert(frame);
}

void ac::MultipleMatrixCollectionSubFilter(cv::Mat &frame) {
    if(subfilter == -1 || ac::draw_strings[subfilter] == "MultipleMatrixCollectionSubFilter")
        return;
    static MatrixCollection<16> collection;
    static MatrixCollection<16> filter_collection;
    static MatrixCollection<16> fcollection;
    cv::Mat copy1 = frame.clone(), copy2 = frame.clone();
    CallFilter(subfilter, copy1);
    Smooth(copy1, &filter_collection);
    Smooth(copy2, &collection);
    AlphaBlend(copy1, copy2, frame, 0.5);
    Smooth(frame, &fcollection);
    MedianBlend(frame);
    AddInvert(frame);
}

// use MedianBlend as Subfilter for cool efffect
void ac::BlurAlphaSubFilter(cv::Mat &frame) {
    if(subfilter == -1 || ac::draw_strings[subfilter] == "BlurAlphaSubFilter")
        return;
    static MatrixCollection<8> collection1,collection2;
    cv::Mat copy1 = frame.clone(), copy2 = frame.clone();
    CallFilter(subfilter, copy1);
    Smooth(copy1, &collection1);
    Smooth(copy2, &collection2);
    AlphaBlend(copy1, copy2, frame, 0.5);
    CallFilter(subfilter, frame);
    AddInvert(frame);
}

void ac::BlurImageSubFilter(cv::Mat &frame) {
    if(blend_set == false || subfilter == -1 || ac::draw_strings[subfilter] == "BlurImageSubFilter")
        return;
    static MatrixCollection<8> collection1, collection2, collection3;
    cv::Mat copy1 = frame.clone(), reimage;
    cv::resize(blend_image, reimage, frame.size());
    CallFilter(subfilter, copy1);
    CallFilter(subfilter, reimage);
    Smooth(copy1, &collection1);
    Smooth(reimage, &collection2);
    AlphaBlend(copy1, reimage, frame, 0.5);
    Smooth(frame, &collection3);
    AddInvert(frame);
}

void ac::MedianBlendSubFilter(cv::Mat &frame) {
    if(subfilter == -1 || ac::draw_strings[subfilter] == "MedianBlendSubFilter")
        return;
    static MatrixCollection<8> collection;
    int r = 3+(rand()%3);
    for(int i = 0; i < r; ++i)
        MedianBlur(frame);
    CallFilter(subfilter, frame);
    cv::Mat copy1 = frame.clone();
    collection.shiftFrames(frame);
    for(int i = 0; i < frame.cols; ++i) {
        for(int z = 0; z < frame.rows; ++z) {
            cv::Scalar value;
            for(int j = 0; j < collection.size(); ++j) {
                cv::Vec3b pixel = collection.frames[j].at<cv::Vec3b>(z, i);
                for(int q = 0; q < 3; ++q) {
                    value[q] += pixel[q];
                }
            }
            cv::Vec3b &pixel = frame.at<cv::Vec3b>(z, i);
            for(int j = 0; j < 3; ++j) {
                int val = 1+static_cast<int>(value[j]);
                pixel[j] = static_cast<unsigned char>(pixel[j] ^ val);
            }
        }
    }
    cv::Mat copy2 = frame.clone();
    AlphaBlend(copy1, copy2, frame, 0.5);
    AddInvert(frame);
}

void ac::MedianBlendImageSubFilter(cv::Mat &frame) {
    if(blend_set == false || subfilter == -1 || ac::draw_strings[subfilter] == "MedianBlendImageSubFilter")
        return;
    static MatrixCollection<8> collection;
    int r = 3+(rand()%3);
    for(int i = 0; i < r; ++i)
        MedianBlur(frame);
    cv::Mat reimage;
    cv::resize(blend_image, reimage, frame.size());
    CallFilter(subfilter, reimage);
    CallFilter(subfilter, frame);
    collection.shiftFrames(frame);
    for(int i = 0; i < frame.cols; ++i) {
        for(int z = 0; z < frame.rows; ++z) {
            cv::Scalar value;
            for(int j = 0; j < collection.size(); ++j) {
                cv::Vec3b pixel = collection.frames[j].at<cv::Vec3b>(z, i);
                for(int q = 0; q < 3; ++q) {
                    value[q] += pixel[q];
                }
            }
            cv::Vec3b &pixel = frame.at<cv::Vec3b>(z, i);
            for(int j = 0; j < 3; ++j) {
                int val = 1+static_cast<int>(value[j]);
                pixel[j] = static_cast<unsigned char>(pixel[j] ^ val);
            }
        }
    }
    cv::Mat copy1 = frame.clone();
    AlphaBlend(copy1, reimage, frame, 0.5);
    AddInvert(frame);
}

void ac::MedianBlendSelfBlend(cv::Mat &frame) {
    cv::Mat copy1 = frame.clone(), copy2 = frame.clone();
    MedianBlend(copy1);
    AlphaBlend(copy1, copy2, frame, 0.5);
    AddInvert(frame);
}

void ac::BlendHalfSubFilter(cv::Mat &frame) {
    if(subfilter == -1 || ac::draw_strings[subfilter] == "BlendHalfSubFilter")
        return;
    cv::Mat copy1 = frame.clone(), copy2 = frame.clone();
    CallFilter(subfilter, copy1);
    AlphaBlend(copy1, copy2, frame, 0.5);
    AddInvert(frame);
}

void ac::BlurImageAlphaBlend(cv::Mat &frame) {
    if(blend_set == false)
        return;
    cv::Mat copy1 = frame.clone(), copy2 = frame.clone();
    cv::Mat reimage;
    cv::resize(blend_image, reimage, frame.size());
    int r = 3+(rand()%3);
    for(int j = 0; j < r; ++j) {
        MedianBlur(copy1);
        MedianBlur(reimage);
    }
    AlphaBlend(copy1, reimage, frame, 0.5);
    AddInvert(frame);
}

void ac::BlurImageAlphaBlendSubFilter(cv::Mat &frame) {
    if(blend_set == false || subfilter == -1 || ac::draw_strings[subfilter] == "BlurImageAlphaBlendSubFilter")
        return;
    cv::Mat reimage, copy1 = frame.clone();
    cv::resize(blend_image, reimage, frame.size());
    int r = 3+(rand()%3);
    for(int j = 0; j < r; ++j) {
        MedianBlur(copy1);
        MedianBlur(reimage);
    }
    CallFilter(subfilter, copy1);
    CallFilter(subfilter, reimage);
    AlphaBlend(copy1, reimage, frame, 0.5);
    AddInvert(frame);
}

void ac::BlurImageAlphaBlendScaleSubFilter(cv::Mat &frame) {
    if(blend_set == false || subfilter == -1 || ac::draw_strings[subfilter] == "BlurImageAlphaBlendScaleSubFilter")
        return;
    cv::Mat reimage, copy1 = frame.clone();
    cv::resize(blend_image, reimage, frame.size());
    int r = 3+(rand()%3);
    for(int j = 0; j < r; ++j) {
        MedianBlur(copy1);
        MedianBlur(reimage);
    }
    CallFilter(subfilter, copy1);
    CallFilter(subfilter, reimage);
    double alpha = 1.0, alpha_max = 4.0;
    static int dir = 1;
    AlphaBlend(copy1, reimage, frame, alpha);
    procPos(dir, alpha, alpha_max, 4.1, 0.01);
    AddInvert(frame);
}

void ac::RandomAmountOfMedianBlur(cv::Mat &frame) {
    int r = 3+(rand()%3);
    for(int j = 0; j < r; ++j)
        MedianBlur(frame);
    
    AddInvert(frame);
}
