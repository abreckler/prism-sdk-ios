# README #

This README documents the steps necessary to get up and running.

### Add PrismRecorder ###

* Drag PrismRecorder.Framework in your Xcode project
* **Make sure "Copy items if needed" is checked**


### Configuration ###

To use all the functionalities of Prism Recorder, you need 3 permissions:

* Photos: Mandatory to access the final recording
* Camera: To record the tester camera
* Mic: to record the tester mic

**On iOS 10 and above, you need to provide the permissions usage description in your Info.plist if you don't already.**
Here's a sample copy, adjust as needed:

*First right-click your Info.plist and select "Open As >> Source code".
*Navigate to the bottom of the file, right before the closing </dict>
*Paste the following:

```
#!plist

    <key>NSMicrophoneUsageDescription</key>
    <string>We use the microphone to record testing audio and sound. Audio is muted if permission isn't granted.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Enable Photos access to save media to your camera roll</string>
    <key>NSCameraUsageDescription</key>
    <string>Enable Camera access to record testing videos.</string>
```



### Launch ###

* Open your AppDelegate.m
* At the top import the PrismRecorder


```
#!objectve-c

@import PrismRecorder
```


* Then in your application:didFinishLaunchingWithOptions configure your Client ID 


```
#!objective-c

[[PrismRecorder sharedManager] enableWithClientId:CLIENTID];
```



### Build and Run ###