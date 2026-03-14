#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *SagasuAutomationRuntimeDescription(void);
FOUNDATION_EXPORT BOOL SagasuAutomationHasCredentialInputs(NSString * _Nullable email, NSString * _Nullable password);

NS_ASSUME_NONNULL_BEGIN

@interface SagasuAutomationSession : NSObject

- (instancetype)init;
- (BOOL)loadURLString:(NSString *)urlString timeout:(NSTimeInterval)timeout error:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)currentURLString;
- (nullable id)evaluateJavaScriptSync:(NSString *)script error:(NSError * _Nullable * _Nullable)error;
- (BOOL)waitForJavaScriptCondition:(NSString *)script
                           timeout:(NSTimeInterval)timeout
                      pollInterval:(NSTimeInterval)pollInterval
                             error:(NSError * _Nullable * _Nullable)error;
- (BOOL)waitForURLMatching:(NSString *)pattern timeout:(NSTimeInterval)timeout error:(NSError * _Nullable * _Nullable)error;
- (void)sleepForMilliseconds:(NSInteger)milliseconds;

@end

NS_ASSUME_NONNULL_END
