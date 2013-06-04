//
//  RZDataImporterMapping.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RZDataManagerModelObjectMapping : NSObject <NSCopying>

@property (nonatomic, strong) NSString *dataIdKey;
@property (nonatomic, strong) NSString *modelIdPropertyName;

- (id)initWithModelClass:(Class)modelClass;

- (NSString*)modelPropertyNameForDataKeyPath:(NSString*)keyPath;
- (void)setModelPropertyName:(NSString*)propertyName forDataKeyPath:(NSString*)dataKeyPath; // in-place override

@end
