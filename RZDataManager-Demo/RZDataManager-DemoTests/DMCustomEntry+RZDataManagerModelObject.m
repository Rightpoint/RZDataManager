//
//  DMCustomEntry+RZDataManagerModelObject.m
//  RZDataManager-Demo
//
//  Created by Nicholas Bonatsakis on 7/11/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "DMCustomEntry+RZDataManagerModelObject.h"

@implementation DMCustomEntry (RZDataManagerModelObject)

+ (NSString*)dataImportDefaultDataIdKey
{
    return @"uid";
}

+ (NSString*)dataImportModelIdPropertyName
{
    return @"uid";
}

- (void)dataImportPerformImportWithData:(NSDictionary *)importData
{
    self.uid = importData[@"uid"];
    NSDictionary *actualDict = importData[@"subDict"];
    self.name = actualDict[@"1"];
    self.age = actualDict[@"2"];
}

@end
