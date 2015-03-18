//
//  VERecorder.m
//  EZAudio
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

#import "VERecorder.h"

#import "EZAudio.h"

@interface VERecorder (){
    ExtAudioFileRef             _destinationFile;
    AudioFileTypeID             _destinationFileTypeID;
    CFURLRef                    _destinationFileURL;
    AudioStreamBasicDescription _destinationFormat;
    AudioStreamBasicDescription _sourceFormat;
}

@end

@implementation VERecorder

#pragma mark - Initializers
-(VERecorder*)initWithDestinationURL:(NSURL*)url
                        sourceFormat:(AudioStreamBasicDescription)sourceFormat
                 destinationFileType:(VERecorderFileType)destinationFileType
{
    self = [super init];
    if( self )
    {
        // Set defaults
        _destinationFile        = NULL;
        _destinationFileURL     = (__bridge CFURLRef)url;
        _sourceFormat           = sourceFormat;
        _destinationFormat      = [VERecorder recorderFormatForFileType:destinationFileType
                                                       withSourceFormat:_sourceFormat];
        _destinationFileTypeID  = [VERecorder recorderFileTypeIdForFileType:destinationFileType
                                                           withSourceFormat:_sourceFormat];
        
        // Initializer the recorder instance
        [self _initializeRecorder];
    }
    return self;
}

#pragma mark - Class Initializers
+(VERecorder*)recorderWithDestinationURL:(NSURL*)url
                            sourceFormat:(AudioStreamBasicDescription)sourceFormat
                     destinationFileType:(VERecorderFileType)destinationFileType
{
    return [[VERecorder alloc] initWithDestinationURL:url
                                         sourceFormat:sourceFormat
                                  destinationFileType:destinationFileType];
}

#pragma mark - Private Configuration
+(AudioStreamBasicDescription)recorderFormatForFileType:(VERecorderFileType)fileType
                                       withSourceFormat:(AudioStreamBasicDescription)sourceFormat
{
//    AudioStreamBasicDescription asbd;
//    switch ( fileType )
//    {
//        case VERecorderFileTypeAIFF:
//            asbd = [EZAudio AIFFFormatWithNumberOfChannels:sourceFormat.mChannelsPerFrame
//                                                sampleRate:sourceFormat.mSampleRate];
//            break;
//        case VERecorderFileTypeM4A:
//            asbd = [EZAudio M4AFormatWithNumberOfChannels:sourceFormat.mChannelsPerFrame
//                                               sampleRate:sourceFormat.mSampleRate];
//            break;
//            
//        case VERecorderFileTypeWAV:
//            asbd = [self stereoFloatInterleavedFormatWithSampleRate:sourceFormat.mSampleRate];
//            break;
//            
//        default:
//            asbd = [EZAudio stereoCanonicalNonInterleavedFormatWithSampleRate:sourceFormat.mSampleRate];
//            break;
//    }
//    return asbd;
    return [VERecorder stereoFloatInterleavedFormatWithSampleRate:sourceFormat.mSampleRate];
}

+(AudioFileTypeID)recorderFileTypeIdForFileType:(VERecorderFileType)fileType
                               withSourceFormat:(AudioStreamBasicDescription)sourceFormat
{
    AudioFileTypeID audioFileTypeID;
    switch ( fileType )
    {
        case VERecorderFileTypeAIFF:
            audioFileTypeID = kAudioFileAIFFType;
            break;
            
        case VERecorderFileTypeM4A:
            audioFileTypeID = kAudioFileM4AType;
            break;
            
        case VERecorderFileTypeWAV:
            audioFileTypeID = kAudioFileWAVEType;
            break;
            
        default:
            audioFileTypeID = kAudioFileWAVEType;
            break;
    }
    return audioFileTypeID;
}

-(void)_initializeRecorder
{
    // Finish filling out the destination format description
    UInt32 propSize = sizeof(_destinationFormat);
    [self checkResult:AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                                                0,
                                                NULL,
                                                &propSize,
                                                &_destinationFormat)
               operation:"Failed to fill out rest of destination format"];
    
    // Create the audio file
    [self checkResult:ExtAudioFileCreateWithURL(_destinationFileURL,
                                                   _destinationFileTypeID,
                                                   &_destinationFormat,
                                                   NULL,
                                                   kAudioFileFlags_EraseFile,
                                                   &_destinationFile)
               operation:"Failed to create audio file"];
    
    // Set the client format (which should be equal to the source format)
    [self checkResult:ExtAudioFileSetProperty(_destinationFile,
                                                 kExtAudioFileProperty_ClientDataFormat,
                                                 sizeof(_sourceFormat),
                                                 &_sourceFormat)
               operation:"Failed to set client format on recorded audio file"];
    
}

#pragma mark - Events
-(void)appendDataFromBufferList:(AudioBufferList *)bufferList
                 withBufferSize:(UInt32)bufferSize
{
    if( _destinationFile )
    {
        [self checkResult:ExtAudioFileWriteAsync(_destinationFile,
                                                    bufferSize,
                                                    bufferList)
                   operation:"Failed to write audio data to recorded audio file"];
    }
}

-(void)closeAudioFile
{
    if( _destinationFile )
    {
        // Dispose of the audio file reference
        [self checkResult:ExtAudioFileDispose(_destinationFile)
                   operation:"Failed to close audio file"];
        
        // Null out the file reference
        _destinationFile = NULL;
    }
}

-(NSURL *)url
{
    return (__bridge NSURL*)_destinationFileURL;
}

#pragma mark - Dealloc
-(void)dealloc
{
    [self closeAudioFile];
}

/// ADDED BY ANDREAS OKHOLM FROM EZAUDIO.h
#pragma mark - OSStatus Utility
-(void)checkResult:(OSStatus)result
         operation:(const char *)operation {
    if (result == noErr) return;
    char errorString[20];
    // see if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(result);
    if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(errorString, "%d", (int)result);
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    exit(1);
}

/// ADDED BY ANDREAS OKHOLM FROM EZAUDIO.h
+(AudioStreamBasicDescription)stereoFloatInterleavedFormatWithSampleRate:(float)sampleRate
{
    AudioStreamBasicDescription asbd;
    UInt32 floatByteSize   = sizeof(float);
    asbd.mChannelsPerFrame = 2;
    asbd.mBitsPerChannel   = 8 * floatByteSize;
    asbd.mBytesPerFrame    = asbd.mChannelsPerFrame * floatByteSize;
    asbd.mBytesPerPacket   = asbd.mChannelsPerFrame * floatByteSize;
    asbd.mFormatFlags      = kAudioFormatFlagIsPacked|kAudioFormatFlagIsFloat;
    asbd.mFormatID         = kAudioFormatLinearPCM;
    asbd.mFramesPerPacket  = 1;
    asbd.mSampleRate       = sampleRate;
    return asbd;
}

@end