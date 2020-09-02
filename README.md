# How to make react-native-intercom handle deep links from push notification payload?

## Problem:

`react-native-intercom` does not allow handling a url from the push notification if application is opened from the background

### Environment:

- `react-native` version 0.59.0 or higher (including 0.63.x)
- `react-native-intercom` version 14.0.0 or higher (including 17.0.0)
- `Intercom` sdk version 6.0.x or higher (including 7.1.1)
- `react-native-push-notification` version 5.0.0 or higher

### Additional dependencies that affect the deep linking of the application

Firebase affects the application in not-release environment by sending a

- `@react-native-firebase/analytics`: "^7.x.x"
- `@react-native-firebase/app`: "^7.x.x"
- `@react-native-firebase/dynamic-links`: "^7.x.x",
- `@react-native-firebase/messaging`: "^7.x.x"

## Why does it happens?

An ios handles deep linking differently, depending on the application state.

1. If application is _launched_ by the deep link either from push notification or from other sources the `didFinishLaunchingWithOptions` method of the AppDelegate is called with the initial link populated in it's `launchOptions`. Then react-native application can access this url later by utilizing `Linking.getInitialURL()`.

2. If application is _opened from background_ by the deep link the `openURL` method of the AppDeleate is called. Then react-native application can access this url later by listening to [`Linking` `url` event](App.js#L22).

3. If application is _on the foreground_ and the deep link is being processed by the `didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler`. It does not trigger anything in react-native-intercom by default.

See native methods in the [`AppDelegate.m`](ios/projectName/AppDelegate.m#L41-L189) file.

### Main issue

`react-native-intercom` does not pass url to an application through [`didFinishLaunchingWithOptions`](ios/projectName/AppDelegate.m#L101) if it's opened from the background. `react-native-intercom` calls [`openURL`](ios/projectName/AppDelegate.m#L67) method immediately after application is launch and `react-native` part of the application misses this event.

## How to solve

In short, you need to create a native [`DeepLink`](App.js#L6) react-native module to lock the thread that handles [`openURL`](ios/projectName/AppDelegate.m#L67) method. Then unlock the thread when your application is ready to handle Linking events.

I'm going to use _Swift_ integration with _Objective-C_ via the bridge to implement the native module and then exposes some of it's methods to you `javascript` code.

1. Go to your xCode project and create `DeepLink.swift` file. xCode will automatically create bridging-header for you. Copy/paste [`DeepLink.swift`](ios/DeepLink.swift) from this repo.
2. Go to your ios folder and create `DeepLink.m` file. This file exposes method for the `javascript` part of the application. Copy/paste [`DeepLink.m`](ios/projectName/DeepLink.m) from this repo.
3. Go to your `AppDelegate.m` file and add lock/unlock capabilites as stated in this repo's [`AppDelegate.m`](ios/projectName/AppDelegate.m#L84) file. Code explanations can be found there.
4. Import your newly created `DeepLink` native module to your `javascript` codebase and call `DeepLink.sendAppCanHandleLinksSignal()` method when your application has finished loading and can properly handle deep linking events. Look at the [`App.js`](App.js#L17) file for the reference.

I've highlighted only the meaningfull files for this fix to not overwhelm you. Try to include all parts of [`AppDelegate.m`](ios/projectName/AppDelegate.m) file and other files to your source code to prevent errors. Also, don't forget to replace values like `<projectName>` with values from your project.

This solution will ensure that any deep-link your application receives while your app is launching will be handled only when your application is ready to handle it. Basically, this is more advanced and convoluted `setTimeout` solution.

## QA

1. Why can't I just made a Pull Request to Intercom to fix this behavior?

Intercom does not expose it's code base (unfortunately) and does not officially support `react-native`. No open-source goodness here, Intercom just ignores react-native community.

## Afterword

I'm not an iOS engineer myself so this solution might not be perfect, but I've tried my best, riding through the debugging hell. I'll try to write down the HOW I've debugged an iOS part of `react-native` application so you'll be more comfortable to do a little tweaking yourself.
I really hope this repo helps you to resolve your `react-native-intercom` issues once and for all.
