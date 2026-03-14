#import "SagasuAutomationObjC.h"

NSString *SagasuAutomationRuntimeDescription(void) {
    return @"Objective-C WebKit automation bridge";
}

BOOL SagasuAutomationHasCredentialInputs(NSString * _Nullable email, NSString * _Nullable password) {
    return email.length > 0 && password.length > 0;
}
