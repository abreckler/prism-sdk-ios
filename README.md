# README #

This README would normally document whatever steps are necessary to get your application up and running.

### add PrismRecorder ###

* Drag PrismRecorder.Framework in your Xcode project
* Make sure "Copy items if needed" is checked


### Configuration ###

To use all the functionalities of Prism Recorder, you need 3 permissions:
* Photos: Mandatory to access the final recording
* Camera: To record the tester camera
* Mic: to record the tester mic

on iOS 10 and above, you need to provide the permissions usage description in your Info.plist if you don't already.

Here's a sample copy, adjust as needed.
First right-click your Info.plist and select "Open As >> Source code".
Navigate to the bottom of the file, right before the closing </dict>
Paste the following:
<pre>
    <key>NSMicrophoneUsageDescription</key>
    <string>We use the microphone to record testing audio and sound. Audio is muted if permission isn't granted.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Enable Photos access to save media to your camera roll</string>
    <key>NSCameraUsageDescription</key>
    <string>Enable Camera access to record testing videos.</string>
</pre>

### Launch ###

* Open your AppDelegate.m
* At the top import the PrismRecorder
<pre>@import PrismRecorder</pre>
* Then in your application:didFinishLaunchingWithOptions configure your Client ID 
<pre> [[PrismRecorder sharedManager] enableWithClientId:CLIENTID];
</pre>

### Build and Run ###