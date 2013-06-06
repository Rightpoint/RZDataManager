//
//  RZDataMangerConstants.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - RZDataManager options dictionary keys

// overrides for mapping

OBJC_EXTERN NSString * const RZDataManagerImportDataIdKey;              // override default data key(path) for uniquely identifying object
OBJC_EXTERN NSString * const RZDataManagerImportModelIdPropertyName;    // override default property name for uniquely identifying object
OBJC_EXTERN NSString * const RZDataManagerImportDateFormat;             // override default date format for import
OBJC_EXTERN NSString * const RZDataManagerImportIgnoreKeys;
OBJC_EXTERN NSString * const RZDataManagerImportKeyMappings;            // override default mappings for keypaths->property names

// other options

OBJC_EXTERN NSString * const RZDataManagerShouldBreakRelationships;     // needs a better name - if true, will break any cached relationships not present in imported data

#pragma mark - Data Type Strings

OBJC_EXTERN NSString* const kRZDataManagerTypeNSArray;
OBJC_EXTERN NSString* const kRZDataManagerTypeNSDictionary;
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

OBJC_EXTERN NSString* const kRZDataManagerUTCDateFormat;

OBJC_EXTERN BOOL rz_isScalarDataType(NSString * rzTypeName);
