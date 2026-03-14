#import "SagasuAutomationObjC.h"
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

static NSString * const SagasuAutomationErrorDomain = @"SagasuAutomationErrorDomain";

@interface SagasuAutomationSession () <WKNavigationDelegate, WKUIDelegate>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, assign) BOOL navigationCompleted;
@property (nonatomic, strong, nullable) NSError *navigationError;

@end

@implementation SagasuAutomationSession

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    [self sagasu_performOnMainThread:^{
        [NSApplication sharedApplication];

        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        configuration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = YES;

        self.webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 1280, 900) configuration:configuration];
        self.webView.navigationDelegate = self;
        self.webView.UIDelegate = self;
    }];

    return self;
}

- (BOOL)loadURLString:(NSString *)urlString timeout:(NSTimeInterval)timeout error:(NSError * _Nullable __autoreleasing *)error {
    __block BOOL success = NO;
    [self sagasu_performOnMainThread:^{
        NSURL *url = [NSURL URLWithString:urlString];
        if (!url) {
            if (error) {
                *error = [NSError errorWithDomain:SagasuAutomationErrorDomain code:100 userInfo:@{ NSLocalizedDescriptionKey: @"Invalid URL string." }];
            }
            return;
        }

        self.navigationCompleted = NO;
        self.navigationError = nil;
        [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
        success = [self sagasu_waitForNavigation:timeout error:error];
    }];
    return success;
}

- (nullable NSString *)currentURLString {
    __block NSString *value = nil;
    [self sagasu_performOnMainThread:^{
        value = self.webView.URL.absoluteString;
    }];
    return value;
}

- (nullable id)evaluateJavaScriptSync:(NSString *)script error:(NSError * _Nullable __autoreleasing *)error {
    __block id value = nil;
    __block NSError *evaluationError = nil;

    [self sagasu_performOnMainThread:^{
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [self.webView evaluateJavaScript:script completionHandler:^(id result, NSError * _Nullable innerError) {
            value = result;
            evaluationError = innerError;
            dispatch_semaphore_signal(semaphore);
        }];

        [self sagasu_spinUntilSemaphore:semaphore timeout:30.0];
    }];

    if (evaluationError && error) {
        *error = evaluationError;
    }

    return value;
}

- (BOOL)waitForJavaScriptCondition:(NSString *)script
                           timeout:(NSTimeInterval)timeout
                      pollInterval:(NSTimeInterval)pollInterval
                             error:(NSError * _Nullable __autoreleasing *)error {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([deadline timeIntervalSinceNow] > 0) {
        NSError *evaluationError = nil;
        id result = [self evaluateJavaScriptSync:script error:&evaluationError];
        if (evaluationError) {
            if (error) {
                *error = evaluationError;
            }
            return NO;
        }

        if ([result isKindOfClass:[NSNumber class]] && [result boolValue]) {
            return YES;
        }

        if ([result isKindOfClass:[NSString class]] && [(NSString *)result length] > 0) {
            return YES;
        }

        [self sleepForMilliseconds:(NSInteger)(pollInterval * 1000)];
    }

    if (error) {
        *error = [NSError errorWithDomain:SagasuAutomationErrorDomain code:101 userInfo:@{ NSLocalizedDescriptionKey: @"Timed out waiting for JavaScript condition." }];
    }
    return NO;
}

- (BOOL)waitForURLMatching:(NSString *)pattern timeout:(NSTimeInterval)timeout error:(NSError * _Nullable __autoreleasing *)error {
    NSError *regexError = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&regexError];
    if (!regex) {
        if (error) {
            *error = regexError;
        }
        return NO;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([deadline timeIntervalSinceNow] > 0) {
        NSString *url = [self currentURLString] ?: @"";
        NSRange range = NSMakeRange(0, url.length);
        if ([regex firstMatchInString:url options:0 range:range] != nil) {
            return YES;
        }
        [self sleepForMilliseconds:200];
    }

    if (error) {
        *error = [NSError errorWithDomain:SagasuAutomationErrorDomain code:102 userInfo:@{ NSLocalizedDescriptionKey: @"Timed out waiting for URL match." }];
    }
    return NO;
}

- (void)sleepForMilliseconds:(NSInteger)milliseconds {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:MAX(0, milliseconds) / 1000.0];
    while ([deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.navigationCompleted = YES;
    self.navigationError = nil;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    self.navigationCompleted = YES;
    self.navigationError = error;
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    self.navigationCompleted = YES;
    self.navigationError = error;
}

- (nullable WKWebView *)webView:(WKWebView *)webView
     createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
                 forNavigationAction:(WKNavigationAction *)navigationAction
                      windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (navigationAction.request.URL) {
        [webView loadRequest:navigationAction.request];
    }
    return nil;
}

- (BOOL)sagasu_waitForNavigation:(NSTimeInterval)timeout error:(NSError * _Nullable __autoreleasing *)error {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!self.navigationCompleted && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }

    if (!self.navigationCompleted) {
        if (error) {
            *error = [NSError errorWithDomain:SagasuAutomationErrorDomain code:103 userInfo:@{ NSLocalizedDescriptionKey: @"Timed out waiting for navigation." }];
        }
        return NO;
    }

    if (self.navigationError) {
        if (error) {
            *error = self.navigationError;
        }
        return NO;
    }

    return YES;
}

- (void)sagasu_spinUntilSemaphore:(dispatch_semaphore_t)semaphore timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([deadline timeIntervalSinceNow] > 0) {
        long status = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)));
        if (status == 0) {
            return;
        }
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)sagasu_performOnMainThread:(dispatch_block_t)block {
    if ([NSThread isMainThread]) {
        block();
        return;
    }

    dispatch_sync(dispatch_get_main_queue(), block);
}

@end

NSString *SagasuAutomationRuntimeDescription(void) {
    return @"Objective-C WebKit automation bridge";
}

BOOL SagasuAutomationHasCredentialInputs(NSString * _Nullable email, NSString * _Nullable password) {
    return email.length > 0 && password.length > 0;
}
