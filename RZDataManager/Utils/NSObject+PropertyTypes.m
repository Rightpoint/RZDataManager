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
        
        static char buffer[256];
        const char * commaLoc = strchr(propAttrString, ','); // find first comma
        int len = (int)(commaLoc - propAttrString - PROP_TYPE_START_OFFS - 1);
        if (commaLoc != NULL){
            memcpy(buffer, propAttrString + PROP_TYPE_START_OFFS, (size_t)len);
            buffer[len] = '\0'; // null terminated
            typenameString = [NSString stringWithUTF8String:buffer];
        }
    }
    
    return typenameString;
}

@end
