#import "AppDelegate.h"

#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTRootView.h>

#import <React/RCTLinkingManager.h>
#import <Firebase.h>
#import "Intercom/intercom.h"

/**
* This are imports to include `https://github.com/zo0r/react-native-push-notification` library
*/
#import <UserNotifications/UserNotifications.h>
#import <RNCPushNotificationIOS.h>

/**
* This will make your swift classes/methods/attributes marked with `@objc` decorator for usage in Objective-C code 
* Replace <projectName> with your xCode project name.
*/
#import "<projectName>-Swift.h"

#if DEBUG && TARGET_OS_SIMULATOR
  #import <FlipperKit/FlipperClient.h>
  #import <FlipperKitLayoutPlugin/FlipperKitLayoutPlugin.h>
  #import <FlipperKitUserDefaultsPlugin/FKUserDefaultsPlugin.h>
  #import <FlipperKitNetworkPlugin/FlipperKitNetworkPlugin.h>
  #import <SKIOSNetworkPlugin/SKIOSNetworkAdapter.h>
  #import <FlipperKitReactPlugin/FlipperKitReactPlugin.h>
  static void InitializeFlipper(UIApplication *application) {
    FlipperClient *client = [FlipperClient sharedClient];
    SKDescriptorMapper *layoutDescriptorMapper = [[SKDescriptorMapper alloc] initWithDefaults];
    [client addPlugin:[[FlipperKitLayoutPlugin alloc] initWithRootNode:application withDescriptorMapper:layoutDescriptorMapper]];
    [client addPlugin:[[FKUserDefaultsPlugin alloc] initWithSuiteName:nil]];
    [client addPlugin:[FlipperKitReactPlugin new]];
    [client addPlugin:[[FlipperKitNetworkPlugin alloc] initWithNetworkAdapter:[SKIOSNetworkAdapter new]]];
    [client start];
  }
#endif

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application continueUserActivity:(nonnull NSUserActivity *)userActivity
 restorationHandler:(nonnull void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
  
   bool handled = [RCTLinkingManager application:application
        continueUserActivity:userActivity
        restorationHandler:restorationHandler];

  return handled;
}

#pragma mark - Handling URLs
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
  return [RCTLinkingManager
           application:application openURL:url
           sourceApplication:sourceApplication
           annotation:annotation
         ];
}

/**
* @summary This method handles deep linking
*/
- (BOOL)application:(UIApplication *)application
openURL:(NSURL *)url
options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
  /**
  * @note Don't handle this link. It breaks intercom push notifications testing in Debug environment on real device
  * if you have firebase google analytics enabled
  */
  NSString *urlString = @"<firebaseDeeplinkURLScheme>://google/link/?dismiss=1&is_weak_match=1";
  NSURL *firebaseInitUrl = [NSURL URLWithString:urlString];
  if ([firebaseInitUrl isEqual:url]) {
    return YES;
  }
    
  /**
  * IMPORTANT
  * This code block locks deep linking thread if application can not handle deep links yet
  */
  dispatch_queue_t queue = dispatch_queue_create("<yourAppName>.openUrlQueue", DISPATCH_QUEUE_CONCURRENT);
  dispatch_async(queue, ^{
    while (!DeepLink.canHandleDeepLinks) {
      [DeepLink.canHandleDeepLinksLock wait];
    }
    [DeepLink.canHandleDeepLinksLock unlock];
    
    // It is CRITICAL to use asynchronious dispatch or you will dead-lock your application startup sequence
    dispatch_async(dispatch_get_main_queue(), ^{
      // This method call will trigger the Linking event with URL to be dispatched to your 'javascript' code
      [RCTLinkingManager application:application openURL:url options:options];
    });
  });
  
  return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  NSString *appId = "INTERCOM_APP_ID"
  NSString *apiKey = "INTERCOM_API_KEY_FOR_IOS";

  [Intercom setApiKey:apiKey forAppId:appId];
  // You can enable intercom process logging for testing purposes
  [Intercom enableLogging];
  
  RCTBridge *bridge = [[RCTBridge alloc] initWithDelegate:self launchOptions:launchOptions];
  RCTRootView *rootView = [[RCTRootView alloc] initWithBridge:bridge moduleName:@"<yourAppName>" initialProperties:nil];

  #pragma mark - Firebase configuration code
  if ([FIRApp defaultApp] == nil) {
    [FIRApp configure];
  }
  [FIROptions defaultOptions].deepLinkURLScheme = @"<firebaseDeeplinkURLScheme>";
  

  #pragma mark - Standart ios root view setup
  rootView.backgroundColor = [[UIColor alloc] initWithRed:1.0f green:1.0f blue:1.0f alpha:1];
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  UIViewController *rootViewController = [UIViewController new];
  rootViewController.view = rootView;
  self.window.rootViewController = rootViewController;
  [self.window makeKeyAndVisible];

  #if DEBUG && TARGET_OS_SIMULATOR
    InitializeFlipper(application);
  #endif
  
  return YES;
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index" fallbackResource:nil];
#else
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
#endif
}

/**
  Push notifications
 */
/**
 Register for remote push notifications
 */
- (void)applicationDidBecomeActive:(UIApplication *)application {
    /**
    * Register application for push notifications
    * For more info, see: https://developers.intercom.com/installing-intercom/docs/ios-push-notifications
    */
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge)
        completionHandler:^(BOOL granted, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // You need to register for remote notifications in the main application thread
                [[UIApplication sharedApplication] registerForRemoteNotifications];
            });
    }];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [Intercom setDeviceToken:deviceToken]; // Required by Intercom

    /**
    * Register for remote notifications handling by 'react-native-push-notification'. It's needed if you want to process arbitrary push notifications (not from intercom).
    */
    [RNCPushNotificationIOS didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}


/**
* This method allows to handle foreground push notifications.
* In this case we just reject a notification without any action and banner/sound so your will not notice it.
* Technically you can call [Intercom completionHandler] here to show notification nonetheless,
* but it will not work as expected and this behavior is not supported by Intercom, so no events will be tracked
*/
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(nonnull void (^)(UIBackgroundFetchResult))completionHandler {
    [Intercom handleIntercomPushNotification:userInfo];
    /**
    * Register for remote notifications handling by 'react-native-push-notification'. It's needed if you want to process arbitrary push notifications (not from intercom).
    */
    [RNCPushNotificationIOS didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler]; 
    completionHandler(UIBackgroundFetchResultNoData);
}

@end
