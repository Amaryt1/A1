#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <substrate.h>

// ============================================================================
// أساسيات الدايلوب: الاستقرار المطلق + حفظ تسجيل الدخول دائمًا
// ============================================================================

static OSStatus (*orig_SecItemAdd)(CFDictionaryRef attributes, CFTypeRef *result);
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result);
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef query, CFDictionaryRef attributesToUpdate);
static OSStatus (*orig_SecItemDelete)(CFDictionaryRef query);

// دالة تنظيف الكيشين لمنع رفض الجلسة بسبب التوقيع
static CFMutableDictionaryRef CleanKeychainQuery(CFDictionaryRef query) {
    if (!query) return NULL;
    CFMutableDictionaryRef mutableDict = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, query);
    
    // إزالة قيود المجموعة والتحكم لضمان القبول تحت أي شهادة
    CFDictionaryRemoveValue(mutableDict, kSecAttrAccessGroup);
    CFDictionaryRemoveValue(mutableDict, kSecAttrAccessControl);
    
    return mutableDict;
}

OSStatus hooked_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    CFMutableDictionaryRef cleaned = CleanKeychainQuery(attributes);
    OSStatus status = orig_SecItemAdd(cleaned ? cleaned : attributes, result);
    if (cleaned) CFRelease(cleaned);
    return status;
}

OSStatus hooked_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    CFMutableDictionaryRef cleaned = CleanKeychainQuery(query);
    OSStatus status = orig_SecItemCopyMatching(cleaned ? cleaned : query, result);
    if (cleaned) CFRelease(cleaned);
    return status;
}

OSStatus hooked_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    CFMutableDictionaryRef cleanedQuery = CleanKeychainQuery(query);
    CFMutableDictionaryRef cleanedAttrs = CleanKeychainQuery(attributesToUpdate);
    
    OSStatus status = orig_SecItemUpdate(cleanedQuery ? cleanedQuery : query, 
                                         cleanedAttrs ? cleanedAttrs : attributesToUpdate);
    
    if (cleanedQuery) CFRelease(cleanedQuery);
    if (cleanedAttrs) CFRelease(cleanedAttrs);
    return status;
}

OSStatus hooked_SecItemDelete(CFDictionaryRef query) {
    CFMutableDictionaryRef cleaned = CleanKeychainQuery(query);
    OSStatus status = orig_SecItemDelete(cleaned ? cleaned : query);
    if (cleaned) CFRelease(cleaned);
    return status;
}

// ============================================================================
// تحميل الدايلوب المباشر عند بدء تشغيل الذاكرة
// ============================================================================
__attribute__((constructor))
static void initEssentialKeychainFix(void) {
    MSHookFunction((void *)SecItemAdd, (void *)hooked_SecItemAdd, (void **)&orig_SecItemAdd);
    MSHookFunction((void *)SecItemCopyMatching, (void *)hooked_SecItemCopyMatching, (void **)&orig_SecItemCopyMatching);
    MSHookFunction((void *)SecItemUpdate, (void *)hooked_SecItemUpdate, (void **)&orig_SecItemUpdate);
    MSHookFunction((void *)SecItemDelete, (void *)hooked_SecItemDelete, (void **)&orig_SecItemDelete);
}
