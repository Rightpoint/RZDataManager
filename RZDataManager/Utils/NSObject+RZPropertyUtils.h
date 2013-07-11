//
//  NSObject+RZPropertyUtils.h
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

OBJC_EXTERN NSString* const kRZDataTypeNSArray;
OBJC_EXTERN NSString* const kRZDataTypeNSDictionary;
OBJC_EXTERN NSString* const kRZDataTypeNSSet;
OBJC_EXTERN NSString* const kRZDataTypeNSOrderedSet;
OBJC_EXTERN NSString* const kRZDataTypeNSString;
OBJC_EXTERN NSString* const kRZDataTypeNSDate;
OBJC_EXTERN NSString* const kRZDataTypeNSNumber;
OBJC_EXTERN NSString* const kRZDataTypeUnsignedChar;
OBJC_EXTERN NSString* const kRZDataTypeChar;
OBJC_EXTERN NSString* const kRZDataTypeInt;
OBJC_EXTERN NSString* const kRZDataTypeUnsignedInt;
OBJC_EXTERN NSString* const kRZDataTypeShort;
OBJC_EXTERN NSString* const kRZDataTypeUnsignedShort;
OBJC_EXTERN NSString* const kRZDataTypeLong;
OBJC_EXTERN NSString* const kRZDataTypeUnsignedLong;
OBJC_EXTERN NSString* const kRZDataTypeLongLong;
OBJC_EXTERN NSString* const kRZDataTypeUnsignedLongLong;
OBJC_EXTERN NSString* const kRZDataTypeFloat;
OBJC_EXTERN NSString* const kRZDataTypeDouble;

OBJC_EXTERN BOOL rz_isScalarDataType(NSString * rzTypeName);
