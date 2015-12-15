VaavudElectronicSDK
===================

DEPRECATED - Created new SDK in swift

iOS SDK for the electronic wind meter. 


Project is setup according to the guide: https://github.com/jverkoey/iOS-Framework
You should add the framework using the following steps (https://github.com/jverkoey/iOS-Framework#developing-the-framework-as-a-dependent-project)

Further down the line a .framework can be made availble for external implementation.


In order to compile the SDK the dependant framework headers for EZaudio needs to be accessible. 
Clone the EZAudio framework into the same super folder as this folder. 
To find the header files a relative path has been specified in "User Header Search Paths" Build setting.

The framework has the following dependencies

CoreLocation
MediaPlayer
EZAudio

