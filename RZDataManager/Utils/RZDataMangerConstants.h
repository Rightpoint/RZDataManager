//
//  RZDataMangerConstants.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RZDataMangerConstants : NSObject

#pragma mark - Mapping Definition Keys

OBJC_EXTERN NSString* const kRZDataManagerDefaultDataIDKey;
OBJC_EXTERN NSString* const kRZDataManagerDataKeyMappings;
OBJC_EXTERN NSString* const kRZDataManagerIgnoreKeys;
OBJC_EXTERN NSString* const kRZDataManagerRelationshipObjectType;
OBJC_EXTERN NSString* const kRZDataManagerRelationshipInverse;
OBJC_EXTERN NSString* const kRZDataManagerFormatStrings;
OBJC_EXTERN NSString* const kRZDataManagerSelectors;
OBJC_EXTERN NSString* const kRZDataManagerDecodeHTML;

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


@end
