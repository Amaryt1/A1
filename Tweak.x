#import <Foundation/Foundation.h>
#import <Security/Security.h>

// ============================================================================
// ماكرو التجسير الخفيف (Dyld Interpose Macro) - يعمل بدون Substrate
// ============================================================================
#define DYLD_INTERPOSE(_replacement,_replacee) \
    __attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
    __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };

// ============================================================================
// دالة تنظيف استعلام الكيشين
// ============================================================================
static CFMutableDictionaryRef CleanKeychainQuery(CFDictionaryRef query) {
    if (!query) return NULL;
    CFMutableDictionaryRef mutableDict = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, query);
    CFDictionaryRemoveValue(mutableDict, kSecAttrAccessGroup);
    CFDictionaryRemoveValue(mutableDict, kSecAttrAccessControl);
    return mutableDict;
}

// ============================================================================
// الاعتراض الآمن لدوال الكيشين
// ============================================================================

OSStatus my_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    CFMutableDictionaryRef cleaned = CleanKeychainQuery(attributes);
    OSStatus status = SecItemAdd(cleaned ? cleaned : attributes, result);
    if (cleaned) CFRelease(cleaned);
    return status;
}
DYLD_INTERPOSE(my_SecItemAdd, SecItemAdd);

OSStatus my_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    CFMutableDictionaryRef cleaned = CleanKeychainQuery(query);
    OSStatus status = SecItemCopyMatching(cleaned ? cleaned : query, result);
    if (cleaned) CFRelease(cleaned);
    return status;
}
DYLD_INTERPOSE(my_SecItemCopyMatching, SecItemCopyMatching);

OSStatus my_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    CFMutableDictionaryRef cleanedQuery = CleanKeychainQuery(query);
    CFMutableDictionaryRef cleanedAttrs = CleanKeychainQuery(attributesToUpdate);
    
    OSStatus status = SecItemUpdate(cleanedQuery ? cleanedQuery : query, 
                                    cleanedAttrs ? cleanedAttrs : attributesToUpdate);
    
    if (cleanedQuery) CFRelease(cleanedQuery);
    if (cleanedAttrs) CFRelease(cleanedAttrs);
    return status;
}
DYLD_INTERPOSE(my_SecItemUpdate, SecItemUpdate);

OSStatus my_SecItemDelete(CFDictionaryRef query) {
    CFMutableDictionaryRef cleaned = CleanKeychainQuery(query);
    OSStatus status = SecItemDelete(cleaned ? cleaned : query);
    if (cleaned) CFRelease(cleaned);
    return status;
}
DYLD_INTERPOSE(my_SecItemDelete, SecItemDelete);

