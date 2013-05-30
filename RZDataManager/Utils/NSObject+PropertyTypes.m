//
//  NSObject+PropertyTypes.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/30/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//
// 

#import "NSObject+PropertyTypes.h"
#import <objc/runtime.h>

// Start of typename in attribute string is 3 characters in
#define PROP_TYPE_START_OFFS 3

@implementation NSObject (PropertyTypes)

- (NSString*)typeNameForProperty:(NSString *)propertyName
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
    
    if ([typenameString isEqualToString:@"f"])
    {
        typenameString = @"float";
    }
    else if ([typenameString isEqualToString:@"d"])
    {
        typenameString = @"double";
    }
    else if ([typenameString isEqualToString:@"i"])
    {
        typenameString = @"int";
    }
    else if ([typenameString isEqualToString:@"I"])
    {
        typenameString = @"unsigned int";
    }
    else if ([typenameString isEqualToString:@"c"])
    {
        typenameString = @"char";
    }
    
    return typenameString;
}

@end
