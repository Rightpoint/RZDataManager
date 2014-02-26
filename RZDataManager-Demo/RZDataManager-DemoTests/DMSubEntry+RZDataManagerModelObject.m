//
//  DMSubEntry+RZDataManagerModelObject.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 2/26/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#import "DMSubEntry+RZDataManagerModelObject.h"

@implementation DMSubEntry (RZDataManagerModelObject)

+ (NSString*)dataImportDefaultDataIdKey
{
    return @"uid";
}

+ (NSString*)dataImportModelIdPropertyName
{
    return @"uid";
}

@end
