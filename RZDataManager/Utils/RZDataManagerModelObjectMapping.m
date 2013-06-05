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
@property (nonatomic, strong) NSMutableDictionary * dataKeyMappings;
@property (nonatomic, strong) NSMutableDictionary * relationshipKeyMappings;
@property (nonatomic, strong) NSMutableDictionary * customSelectorKeyMappings;

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

- (NSString*)modelPropertyNameForDataKey:(NSString *)key
{
    NSString *propName = [self.dataKeyMappings objectForKey:key];
    if (nil == propName){
        
        // look for property name similar to key/keypath, if found, cache it
        NSPredicate *propnamePred = [NSPredicate predicateWithFormat:@"SELF LIKE[cd] %@", key];
        NSArray *matches = [self.classPropertyNames filteredArrayUsingPredicate:propnamePred];
        if (matches.count > 0){
            propName = [matches objectAtIndex:0];
            [self.dataKeyMappings setObject:propName forKey:key];
        }
        
    }
    return propName;
}

- (void)setModelPropertyName:(NSString *)propertyName forDataKey:(NSString *)key
{
    if (nil == self.dataKeyMappings){
        self.dataKeyMappings = [NSMutableDictionary dictionary];
    }
    [self.dataKeyMappings setObject:propertyName forKey:key];
}

- (RZDataManagerModelObjectRelationshipMapping*)relationshipMappingForDataKey:(NSString *)key
{
    return [self.relationshipKeyMappings objectForKey:key];
}

- (void)setRelationshipMapping:(RZDataManagerModelObjectRelationshipMapping *)mapping forDataKey:(NSString *)key
{
    if (nil == self.relationshipKeyMappings){
        self.relationshipKeyMappings = [NSMutableDictionary dictionary];
    }
    [self.relationshipKeyMappings setObject:mapping forKey:key];
}

- (NSString*)importSelectorNameForDataKey:(NSString*)key
{
    return [self.customSelectorKeyMappings objectForKey:key];
}

- (void)setImportSelectorName:(NSString*)selName forDataKey:(NSString*)key
{
    if (nil == self.customSelectorKeyMappings){
        self.customSelectorKeyMappings = [NSMutableDictionary dictionary];
    }
    [self.customSelectorKeyMappings setObject:selName forKey:key];
}

#pragma mark - Private

- (void)buildMappingCache
{
    self.classPropertyNames = [[self.modelClass class] getPropertyNames];
    self.dataIdKey = [[self.modelClass class] defaultDataIdKey];
    self.modelIdPropertyName = [[self.modelClass class] modelIdPropertyName];
    
    if ([[self.modelClass class] respondsToSelector:@selector(dataImportDateFormat)])
    {
        self.dateFormat = [[self.modelClass class] dataImportDateFormat];
    }
    
    if ([[self.modelClass class] respondsToSelector:@selector(dataImportIgnoreKeys)])
    {
        self.ignoreKeys = [[self.modelClass class] dataImportIgnoreKeys];
    }
    
    if ([[self.modelClass class] respondsToSelector:@selector(dataImportKeyMappings)])
    {
        self.dataKeyMappings = [[[self.modelClass class] dataImportKeyMappings] mutableCopy];
    }
    
    if ([[self.modelClass class] respondsToSelector:@selector(dataImportRelationshipKeyMappings)])
    {
        self.relationshipKeyMappings = [[[self.modelClass class] dataImportRelationshipKeyMappings] mutableCopy];
    }
    
    if ([[self.modelClass class] respondsToSelector:@selector(dataImportCustomSelectorKeyMappings)])
    {
        self.customSelectorKeyMappings = [[[self.modelClass class] dataImportCustomSelectorKeyMappings] mutableCopy];
    }
}

#pragma mark - Copying

- (id)copyWithZone:(NSZone *)zone
{
    RZDataManagerModelObjectMapping *mapping = [[RZDataManagerModelObjectMapping alloc] init];
    mapping.dataIdKey = self.dataIdKey;
    mapping.modelIdPropertyName = self.modelIdPropertyName;
    mapping.dateFormat = self.dateFormat;
    mapping.ignoreKeys = [self.ignoreKeys copy];
    mapping.modelClass = self.modelClass;
    mapping.classPropertyNames = [self.classPropertyNames copy];
    mapping.dataKeyMappings = [self.dataKeyMappings mutableCopy];
    mapping.customSelectorKeyMappings = [self.customSelectorKeyMappings mutableCopy];
    
    // deep copy relationship key mappings
    mapping.relationshipKeyMappings = [NSMutableDictionary dictionary];
    [self.relationshipKeyMappings enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [mapping.relationshipKeyMappings setObject:[obj copy] forKey:key];
    }];
    
    return mapping;
}

@end

@implementation RZDataManagerModelObjectRelationshipMapping

+ (RZDataManagerModelObjectRelationshipMapping*)mappingWithObjectType:(NSString *)type inversePropertyName:(NSString *)inverse
{
    RZDataManagerModelObjectRelationshipMapping *mapping = [[RZDataManagerModelObjectRelationshipMapping alloc] init];
    mapping.relationshipObjectType = type;
    mapping.relationshipInversePropertyName = inverse;
    return mapping;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [RZDataManagerModelObjectRelationshipMapping mappingWithObjectType:self.relationshipObjectType inversePropertyName:self.relationshipInversePropertyName];
}

@end
