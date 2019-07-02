// Copyright 2015-present 650 Industries. All rights reserved.

#import "EXUserNotificationManager.h"
#import "EXKernel.h"
#import "EXRemoteNotificationManager.h"
#import "EXEnvironment.h"

static NSString * const scopedIdentifierSeparator = @":";

@interface EXUserNotificationManager ()

@property (nonatomic, strong) EXPendingNotification *pendingNotification;

@end

@implementation EXUserNotificationManager

- (EXPendingNotification *)initialNotificationForExperience:(NSString *)experienceId
{
  if ([EXEnvironment sharedEnvironment].isDetached) {
    return _pendingNotification;
  }

  return nil;
}

# pragma mark - EXNotificationsIdentifiersManager

- (NSString *)internalIdForIdentifier:(NSString *)identifier experienceId:(nonnull NSString *)experienceId
{
  if ([EXEnvironment sharedEnvironment].isDetached) {
    return identifier;
  }
  return [NSString stringWithFormat:@"%@%@%@", experienceId, scopedIdentifierSeparator, identifier];
}

- (NSString *)exportedIdForInternalIdentifier:(NSString *)identifier
{
  if ([EXEnvironment sharedEnvironment].isDetached) {
    return identifier;
  }
  NSArray<NSString *> *components = [identifier componentsSeparatedByString:scopedIdentifierSeparator];
  return [[components subarrayWithRange:NSMakeRange(1, components.count - 1)] componentsJoinedByString:scopedIdentifierSeparator];
}

# pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler
{
  EXPendingNotification *pendingNotification = [[EXPendingNotification alloc] initWithNotificationResponse:response identifiersManager:self];
  if (![[EXKernel sharedInstance] sendNotification:pendingNotification] && [EXEnvironment sharedEnvironment].isDetached) {
    _pendingNotification = pendingNotification;
  }
  completionHandler();
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
  // Notifications were only shown while the app wasn't active,
  // or if the user specifies `_displayInForeground` to be `true`.
  NSDictionary *userInfo = notification.request.content.userInfo;
  if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive ||
     (userInfo && userInfo[@"body"] && userInfo[@"body"][@"_displayInForeground"] && [userInfo[@"body"][@"_displayInForeground"] boolValue])) {    completionHandler(
                      UNNotificationPresentationOptionAlert +
                      UNNotificationPresentationOptionSound +
                      UNNotificationPresentationOptionBadge
                      );
    return;
  }
  // If the app is active we do not show the alert, but we deliver the notification to the experience.

  EXPendingNotification *pendingNotification = [[EXPendingNotification alloc] initWithNotification:notification];
  if (![[EXKernel sharedInstance] sendNotification:pendingNotification] && [EXEnvironment sharedEnvironment].isDetached) {
    _pendingNotification = pendingNotification;
  }

  completionHandler(UNNotificationPresentationOptionNone);
}

@end
