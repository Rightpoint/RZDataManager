//
//  DMThingClass.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/6/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "DMThingClass.h"

@implementation DMThingClass

@dynamic attribute1;
@dynamic attribute2;
@dynamic myIdentifier;

@synthesize someOtherProperty = _someOtherProperty;

+ (NSString*)dataImportDefaultDataIdKey
{
    return @"id";
}

+ (NSString*)dataImportModelIdPropertyName
{
    return @"myIdentifier";
}

@end
