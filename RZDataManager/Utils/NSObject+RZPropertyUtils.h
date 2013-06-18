//
//  NSObject+PropertyTypes.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/30/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (RZPropertyUtils)

+ (BOOL)rz_hasPropertyNamed:(NSString*)propertyName;

+ (NSArray*)rz_getPropertyNames;

+ (NSString*)rz_dataTypeForPropertyNamed:(NSString*)propertyName;

+ (SEL)rz_getterForPropertyNamed:(NSString*)propertyName;

+ (SEL)rz_setterForPropertyNamed:(NSString*)propertyName;

@end

#pragma mark - Data type string constants and helpers

OBJC_EXTERN NSString* const kRZDataManagerTypeNSArray;
OBJC_EXTERN NSString* const kRZDataManagerTypeNSDictionary;
OBJC_EXTERN NSString* const kRZDataManagerTypeNSSet;
OBJC_EXTERN NSString* const kRZDataManagerTypeNSOrderedSet;
OBJC_EXTERN NSString* const kRZDataManagerTypeNSString;
OBJC_EXTERN NSString* const kRZDataManagerTypeNSDate;
OBJC_EXTERN NSString* const kRZDataManagerTypeNSNumber;
OBJC_EXTERN NSString* const kRZDataManagerTypeUnsignedChar;
OBJC_EXTERN NSString* const kRZDataManagerTypeChar;
OBJC_EXTERN NSString* const kRZDataManagerTypeInt;
OBJC_EXTERN NSString* const kRZDataManagerTypeUnsignedInt;
OBJC_EXTERN NSString* const kRZDataManagerTypeShort;
OBJC_EXTERN NSString* const kRZDataManagerTypeUnsignedShort;
OBJC_EXTERN NSString* const kRZDataManagerTypeLong;
OBJC_EXTERN NSString* const kRZDataManagerTypeUnsignedLong;
OBJC_EXTERN NSString* const kRZDataManagerTypeLongLong;
OBJC_EXTERN NSString* const kRZDataManagerTypeUnsignedLongLong;
OBJC_EXTERN NSString* const kRZDataManagerTypeFloat;
OBJC_EXTERN NSString* const kRZDataManagerTypeDouble;

OBJC_EXTERN BOOL rz_isScalarDataType(NSString * rzTypeName);
