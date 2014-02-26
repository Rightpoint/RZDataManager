//
//  DMEntry+RZDataManagerModelObject.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "DMEntry+RZDataManagerModelObject.h"

@implementation DMEntry (RZDataManagerModelObject)

+ (NSString*)dataImportDefaultDataIdKey
{
    return @"uid";
}

+ (NSString*)dataImportModelIdPropertyName
{
    return @"uid";
}

+ (NSDictionary*)dataImportKeyMappings
{
    return @{ @"date" : @"createdDate" };
}

+ (NSDictionary*)dataImportRelationshipKeyMappings
{
    return @{ @"collection" : [RZDataManagerModelObjectRelationshipMapping mappingWithClassNamed:@"DMCollection" propertyName:@"collection" inversePropertyName:@"entries"],
              @"subEntry" : [RZDataManagerModelObjectRelationshipMapping mappingWithClassNamed:@"DMSubEntry" propertyName:@"subEntry" inversePropertyName:@"entry"]};
}

@end
