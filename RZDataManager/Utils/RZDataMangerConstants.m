//
//  RZDataMangerConstants.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataMangerConstants.h"


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

// Scalar type names
static NSArray * scalarTypeNames = nil;

__attribute__((constructor))
static void initialize_rzScalarTypeNames() {
    scalarTypeNames = @[kRZDataManagerTypeChar,
                        kRZDataManagerTypeDouble,
                        kRZDataManagerTypeFloat,
                        kRZDataManagerTypeInt,
                        kRZDataManagerTypeLong,
                        kRZDataManagerTypeLongLong,
                        kRZDataManagerTypeShort,
                        kRZDataManagerTypeUnsignedChar,
                        kRZDataManagerTypeUnsignedInt,
                        kRZDataManagerTypeUnsignedLong,
                        kRZDataManagerTypeUnsignedLongLong,
                        kRZDataManagerTypeUnsignedShort];
}

__attribute__((destructor))
static void destroy_rzScalarTypeNames() {
    scalarTypeNames = nil;
}

BOOL rz_isScalarDataType(NSString * rzTypeName)
{
    return [scalarTypeNames containsObject:rzTypeName];
}