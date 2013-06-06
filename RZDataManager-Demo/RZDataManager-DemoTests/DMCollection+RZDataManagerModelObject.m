//
//  DMCollection+RZDataManagerModelObject.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "DMCollection+RZDataManagerModelObject.h"

@implementation DMCollection (RZDataManagerModelObject)

+ (NSString*)defaultDataIdKey
{
    return @"name";
}

+ (NSString*)modelIdPropertyName
{
    return @"name";
}

+ (NSDictionary*)dataImportRelationshipKeyMappings
{
    return @{ @"entries" : [RZDataManagerModelObjectRelationshipMapping mappingWithObjectType:@"DMEntry" propertyName:@"entries" inversePropertyName:@"collection"] };
}

@end
