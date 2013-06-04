//
//  RZDataImporterMapping.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataManagerModelObjectMapping.h"
#import "RZDataManagerModelObject.h"
#import "NSObject+RZPropertyUtils.h"

@interface RZDataManagerModelObjectMapping ()

@property (nonatomic, assign) Class modelClass;
@property (nonatomic, strong) NSArray *classPropertyNames;
@property (nonatomic, strong) NSMutableDictionary * dataImportKeyMappings;

- (void)buildMappingCache;

@end

@implementation RZDataManagerModelObjectMapping

- (id)initWithModelClass:(Class)modelClass
{
    self = [super init];
    if (self){
        self.modelClass = modelClass;
        [self buildMappingCache];
    }
    return self;
}

- (NSString*)modelPropertyNameForDataKeyPath:(NSString *)keyPath
{
    NSString *propName = [self.dataImportKeyMappings objectForKey:keyPath];
    if (nil == propName){
        
        // look for property name similar to key/keypath, if found, cache it
        NSPredicate *propnamePred = [NSPredicate predicateWithFormat:@"SELF LIKE[cd] %@", keyPath];
        NSArray *matches = [self.classPropertyNames filteredArrayUsingPredicate:propnamePred];
        if (matches.count > 0){
            propName = [matches objectAtIndex:0];
            [self.dataImportKeyMappings setObject:propName forKey:keyPath];
        }
        
    }
    return propName;
}

#pragma mark - Private

- (void)buildMappingCache
{
    self.classPropertyNames = [[self.modelClass class] getPropertyNames];
    
    self.dataIdKey = [[self.modelClass class] defaultDataIdKey];
    self.modelIdPropertyName = [[self.modelClass class] modelIdPropertyName];
    
    if ([[self.modelClass class] respondsToSelector:@selector(dataImportKeyMappings)])
    {
        self.dataImportKeyMappings = [[[self.modelClass class] dataImportKeyMappings] mutableCopy];
    }
}

- (void)setModelPropertyName:(NSString *)propertyName forDataKeyPath:(NSString *)dataKeyPath
{
    if (nil == self.dataImportKeyMappings){
        self.dataImportKeyMappings = [NSMutableDictionary dictionary];
    }
    
    [self.dataImportKeyMappings setObject:propertyName forKey:dataKeyPath];
}


#pragma mark - Copying

- (id)copyWithZone:(NSZone *)zone
{
    RZDataManagerModelObjectMapping *mapping = [[RZDataManagerModelObjectMapping alloc] init];
    mapping.modelClass = self.modelClass;
    mapping.classPropertyNames = [self.classPropertyNames copy];
    mapping.dataImportKeyMappings = [self.dataImportKeyMappings mutableCopy];
    return mapping;
}

@end
