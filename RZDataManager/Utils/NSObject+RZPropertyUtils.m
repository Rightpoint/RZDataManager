//
//  NSObject+PropertyTypes.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/30/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//
// 

#import "NSObject+RZPropertyUtils.h"
#import "RZDataMangerConstants.h"
#import <objc/runtime.h>

// Start of typename in attribute string is 3 characters in
#define PROP_TYPE_START_OFFS 3

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

+ (BOOL)hasPropertyNamed:(NSString *)propertyName
{
    return (class_getProperty([self class], [propertyName UTF8String]) != NULL);
}

+ (NSArray*)getPropertyNames
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

+ (NSString*)dataTypeForPropertyNamed:(NSString *)propertyName
{
    NSString * typenameString = nil;
    objc_property_t property = class_getProperty([self class], [propertyName UTF8String]);
    const char * propAttrString = property_getAttributes(property);
    
    if (propAttrString != NULL){
        
        NSString * propString = [NSString stringWithUTF8String:propAttrString];
        
        NSScanner *scanner = [NSScanner scannerWithString:propString];
        [scanner setCaseSensitive:YES];
        [scanner setCharactersToBeSkipped:nil];
        
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

@end
