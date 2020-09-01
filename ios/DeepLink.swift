//  Created by react-native-create-bridge
import Foundation

@objc(DeepLink)
class DeepLink : NSObject {
  @objc
  static var canHandleDeepLinksLock = {
    var condition =  NSCondition.init();
    condition.lock();
    return condition;
    }() as NSCondition;
  
  @objc
  static var canHandleDeepLinks = false;
  
  @objc
  func sendAppCanHandleLinksSignal(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void {
    resolve(nil);

    DeepLink.canHandleDeepLinks = true;
    DeepLink.canHandleDeepLinksLock.signal();
    DeepLink.canHandleDeepLinksLock.unlock();
  }
  
  @objc
  func canHandleDeepLinks() -> Bool {
    return DeepLink.canHandleDeepLinks;
  }
}
