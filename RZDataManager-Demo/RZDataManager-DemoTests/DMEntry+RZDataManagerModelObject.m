//
//  DMEntry+RZDataManagerModelObject.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "DMEntry+RZDataManagerModelObject.h"

@implementation DMEntry (RZDataManagerModelObject)

+ (NSString*)defaultDataIdKey
{
    return @"uid";
}

+ (NSString*)modelIdPropertyName
{
    return @"uid";
}

+ (NSDictionary*)dataImportKeyMappings
{
    return @{ @"date" : @"createdDate" };
}

+ (NSDictionary*)dataImportRelationshipKeyMappings
{
    return @{ @"collection" : [RZDataManagerModelObjectRelationshipMapping mappingWithObjectType:@"DMCollection" inversePropertyName:@"entries"] };
}

@end
