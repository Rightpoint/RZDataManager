//
//  NSObject+PropertyTypes.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/30/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//
// 

#import "NSObject+RZPropertyUtils.h"
#import <objc/runtime.h>

NSString* const kRZDataManagerTypeNSArray               = @"NSArray";
NSString* const kRZDataManagerTypeNSDictionary          = @"NSDictionary";
NSString* const kRZDataManagerTypeNSSet                 = @"NSSet";
NSString* const kRZDataManagerTypeNSOrderedSet          = @"NSOrderedSet";
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

static NSDictionary * rz_TypeMappings = nil;

// Statically allocate lookup dictionary for efficinent lookup of objc scalar type mappings to string constants
__attribute__((constructor))
static void initialize_rzTypeMappings() {
    rz_TypeMappings = @{
                            @"f" : kRZDataManagerTypeFloat,
                            @"d" : kRZDataManagerTypeDouble,
                            @"i" : kRZDataManagerTypeInt,
                            @"I" : kRZDataManagerTypeUnsignedInt,
                            @"s" : kRZDataManagerTypeShort,
                            @"S" : kRZDataManagerTypeUnsignedShort,
                            @"l" : kRZDataManagerTypeLong,
                            @"L" : kRZDataManagerTypeUnsignedLong,
                            @"q" : kRZDataManagerTypeLongLong,
                            @"Q" : kRZDataManagerTypeUnsignedLongLong,
                            @"c" : kRZDataManagerTypeChar,
                            @"C" : kRZDataManagerTypeUnsignedChar
                        };
}

__attribute__((destructor))
static void destroy_rzTypeMappings() {
    rz_TypeMappings = nil;
}


@implementation NSObject (RZPropertyUtils)

+ (BOOL)rz_hasPropertyNamed:(NSString *)propertyName
{
    return (class_getProperty([self class], [propertyName UTF8String]) != NULL);
}

+ (NSArray*)rz_getPropertyNames
{
    unsigned int count;
    objc_property_t * properties = class_copyPropertyList([self class], &count);
    
    NSMutableArray *names = [NSMutableArray array];
    
    for (unsigned int i=0; i<count; i++){
        
        objc_property_t property = properties[i];
        [names addObject:[NSString stringWithUTF8String:property_getName(property)]];
    }
    
    return names;
}

+ (NSString*)rz_dataTypeForPropertyNamed:(NSString *)propertyName
{
    NSString * typenameString = nil;
    objc_property_t property = class_getProperty([self class], [propertyName UTF8String]);
    const char * propAttrString = property_getAttributes(property);
    
    if (propAttrString != NULL){
        
        NSString * propString = [NSString stringWithUTF8String:propAttrString];
        
        NSScanner *scanner = [NSScanner scannerWithString:propString];
        [scanner setCaseSensitive:YES];
        [scanner setCharactersToBeSkipped:nil];
        
        // Type is first part of property string, no need to split components
        if ([scanner scanString:@"T" intoString:NULL]){
            [scanner scanUpToString:@"," intoString:&typenameString];
            typenameString = [typenameString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@\""]];
        }
    }
    
    if (typenameString){
        NSString *mappedType = [rz_TypeMappings objectForKey:typenameString];
        if (mappedType){
            typenameString = mappedType;
        }
    }
    
    return typenameString;
}

+ (SEL)rz_getterForPropertyNamed:(NSString *)propertyName
{
    __block NSString * getterString = propertyName;
    objc_property_t property = class_getProperty([self class], [propertyName UTF8String]);
    const char * propAttrString = property_getAttributes(property);
    
    if (propAttrString != NULL){
        
        NSString * propString = [NSString stringWithUTF8String:propAttrString];
        NSArray *propComponents = [propString componentsSeparatedByString:@","];
        [propComponents enumerateObjectsUsingBlock:^(NSString *c, NSUInteger idx, BOOL *stop) {
            if ([c characterAtIndex:0] == 'G')
            {
                getterString = [c substringFromIndex:1];
                *stop = YES;
            }
        }];
    }
    
    return NSSelectorFromString(getterString);
}

+ (SEL)rz_setterForPropertyNamed:(NSString *)propertyName
{
    __block NSString * setterString = [NSString stringWithFormat:@"set%@", propertyName.capitalizedString];
    objc_property_t property = class_getProperty([self class], [propertyName UTF8String]);
    const char * propAttrString = property_getAttributes(property);
    
    if (propAttrString != NULL){
        
        NSString * propString = [NSString stringWithUTF8String:propAttrString];
        NSArray *propComponents = [propString componentsSeparatedByString:@","];
        [propComponents enumerateObjectsUsingBlock:^(NSString *c, NSUInteger idx, BOOL *stop) {
            if ([c characterAtIndex:0] == 'S')
            {
                setterString = [c substringFromIndex:1];
                *stop = YES;
            }
        }];
    }
    
    return NSSelectorFromString(setterString);
}

@end
