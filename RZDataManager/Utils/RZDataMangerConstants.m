//
//  RZDataMangerConstants.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataMangerConstants.h"

@implementation RZDataMangerConstants

#pragma mark - RZDataManager option keys

NSString * const RZDataManagerImportDataIdKey               = @"RZDataManagerImportDataIdKey";
NSString * const RZDataManagerImportModelIdPropertyName     = @"RZDataManagerImportModelIdPropertyName";
NSString * const RZDataManagerShouldBreakRelationships      = @"RZDataManagerShouldBreakRelationships";
NSString * const RZDataManagerImportDateFormat              = @"RZDataManagerImportDateFormat";
NSString * const RZDataManagerImportIgnoreKeys              = @"RZDataManagerImportIgnoreKeys";
NSString * const RZDataManagerImportKeyMappings             = @"RZDataManagerImportKeyMappings";

#pragma mark - Data Type Strings

NSString* const kRZDataManagerTypeNSArray               = @"NSArray";
NSString* const kRZDataManagerTypeNSDictionary          = @"NSDictionary";
NSString* const kRZDataManagerTypeNSString              = @"NSString";
NSString* const kRZDataManagerTypeNSDate                = @"NSDate";
NSString* const kRZDataManagerTypeNSNumber              = @"NSNumber";
NSString* const kRZDataManagerTypeUnsignedChar          = @"unsigned char";
NSString* const kRZDataManagerTypeChar                  = @"char";
NSString* const kRZDataManagerTypeShort                 = @"short";
NSString* const kRZDataManagerTypeUnsignedShort         = @"unsigned short";
NSString* const kRZDataManagerTypeInt                   = @"int";
NSString* const kRZDataManagerTypeUnsignedInt           = @"unsigned int";
NSString* const kRZDataManagerTypeLong                  = @"long";
NSString* const kRZDataManagerTypeUnsignedLong          = @"unsigned long";
NSString* const kRZDataManagerTypeLongLong              = @"long long";
NSString* const kRZDataManagerTypeUnsignedLongLong      = @"unsigned long long";
NSString* const kRZDataManagerTypeFloat                 = @"float";
NSString* const kRZDataManagerTypeDouble                = @"double";

NSString* const kRZDataManagerUTCDateFormat             = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'";

@end
