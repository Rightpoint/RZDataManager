//
//  NSObject+PropertyTypes.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/30/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (RZPropertyUtils)

+ (BOOL)hasPropertyNamed:(NSString*)propertyName;

+ (NSArray*)getPropertyNames;

+ (NSString*)dataTypeForPropertyNamed:(NSString*)propertyName;

@end
