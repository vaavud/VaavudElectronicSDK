//
//  VERecorder.h // RENAME TO AVOID NAMING NAMING CONFLICT IF USING EZAUDIO AS EXTERNAL LIBRARY
//
//  Created by Syed Haris Ali on 12/1/13.
//  Copyright (c) 2013 Syed Haris Ali. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

/**
 To ensure valid recording formats are used when recording to a file the VERecorderFileType describes the most common file types that a file can be encoded in. Each of these types can be used to output recordings as such:
 
 VERecorderFileTypeAIFF - .aif, .aiff, .aifc, .aac
 VERecorderFileTypeM4A  - .m4a, .mp4
 VERecorderFileTypeWAV  - .wav
 
 */
typedef NS_ENUM(NSInteger, VERecorderFileType)
{
    /**
     Recording format that describes AIFF file types. These are uncompressed, LPCM files that are completely lossless, but are large in file size.
     */
    VERecorderFileTypeAIFF,
    /**
     Recording format that describes M4A file types. These are compressed, but yield great results especially when file size is an issue.
     */
    VERecorderFileTypeM4A,
    /**
     Recording format that describes WAV file types. These are uncompressed, LPCM files that are completely lossless, but are large in file size.
     */
    VERecorderFileTypeWAV
};

/**
 The VERecorder provides a flexible way to create an audio file and append raw audio data to it. The VERecorder will convert the incoming audio on the fly to the destination format so no conversion is needed between this and any other component. Right now the only supported output format is 'caf'. Each output file should have its own VERecorder instance (think 1 VERecorder = 1 audio file).
 */
@interface VERecorder : NSObject

#pragma mark - Initializers
///-----------------------------------------------------------
/// @name Initializers
///-----------------------------------------------------------

/**
 Creates a new instance of an VERecorder using a destination file path URL and the source format of the incoming audio.
 @param url                 An NSURL specifying the file path location of where the audio file should be written to.
 @param sourceFormat        The AudioStreamBasicDescription for the incoming audio that will be written to the file.
 @param destinationFileType A constant described by the VERecorderFileType that corresponds to the type of destination file that should be written. For instance, an AAC file written using an '.m4a' extension would correspond to VERecorderFileTypeM4A. See VERecorderFileType for all the constants and mapping combinations.
 @return The newly created VERecorder instance.
 */
-(VERecorder*)initWithDestinationURL:(NSURL*)url
                        sourceFormat:(AudioStreamBasicDescription)sourceFormat
                 destinationFileType:(VERecorderFileType)destinationFileType;


#pragma mark - Class Initializers
///-----------------------------------------------------------
/// @name Class Initializers
///-----------------------------------------------------------

/**
 Class method to create a new instance of an VERecorder using a destination file path URL and the source format of the incoming audio.
 @param url                 An NSURL specifying the file path location of where the audio file should be written to.
 @param sourceFormat        The AudioStreamBasicDescription for the incoming audio that will be written to the file.
 @param destinationFileType A constant described by the VERecorderFileType that corresponds to the type of destination file that should be written. For instance, an AAC file written using an '.m4a' extension would correspond to VERecorderFileTypeM4A. See VERecorderFileType for all the constants and mapping combinations.
 @return The newly created VERecorder instance.
 */
+(VERecorder*)recorderWithDestinationURL:(NSURL*)url
                            sourceFormat:(AudioStreamBasicDescription)sourceFormat
                     destinationFileType:(VERecorderFileType)destinationFileType;

#pragma mark - Getters
///-----------------------------------------------------------
/// @name Getting The Recorder's Properties
///-----------------------------------------------------------
/**
 Provides the file path that's currently being used by the recorder.
 @return  The NSURL representing the file path of the audio file path being used for recording.
 */
-(NSURL*)url;

#pragma mark - Events
///-----------------------------------------------------------
/// @name Appending Data To The Audio File
///-----------------------------------------------------------

/**
 Appends audio data to the tail of the output file from an AudioBufferList.
 @param bufferList The AudioBufferList holding the audio data to append
 @param bufferSize The size of each of the buffers in the buffer list.
 */
-(void)appendDataFromBufferList:(AudioBufferList*)bufferList
                 withBufferSize:(UInt32)bufferSize;

///-----------------------------------------------------------
/// @name Closing The Audio File
///-----------------------------------------------------------

/**
 Finishes writes to the audio file and closes it.
 */
-(void)closeAudioFile;

//ADDED
/**
 
 @param sampleRate The desired sample rate
 @return A new AudioStreamBasicDescription with the specified format.
 */
+(AudioStreamBasicDescription)stereoFloatInterleavedFormatWithSampleRate:(float)sampleRate;


@end