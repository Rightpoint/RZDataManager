//
//  RZDataImporterMapping.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataManagerModelObjectMapping.h"
#import "RZDataManagerModelObject.h"
#import "RZDataMangerConstants.h"
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

- (void)applyOptions:(NSDictionary *)options
{
    [options enumerateKeysAndObjectsUsingBlock:^(NSString * key, id obj, BOOL *stop) {
        
        if ([key isEqualToString:RZDataManagerImportDataIdKey] && [obj isKindOfClass:[NSString class]]){
            self.dataIdKey = obj;
        }
        else if ([key isEqualToString:RZDataManagerImportModelIdPropertyName] && [obj isKindOfClass:[NSString class]]){
            self.modelIdPropertyName = obj;
        }
        else if ([key isEqualToString:RZDataManagerImportDateFormat] && [obj isKindOfClass:[NSString class]]){
            self.dateFormat = obj;
        }
        else if ([key isEqualToString:RZDataManagerImportIgnoreKeys] && [obj isKindOfClass:[NSArray class]]){
            if (self.ignoreKeys){
                NSMutableArray * ignoreKeys = [self.ignoreKeys mutableCopy];
                [ignoreKeys addObjectsFromArray:obj];
                self.ignoreKeys = ignoreKeys;
            }
            else{
                self.ignoreKeys = obj;
            }
        }
        else if ([key isEqualToString:RZDataManagerImportKeyMappings] && [obj isKindOfClass:[NSDictionary class]]){
            if (self.dataKeyMappings){
                [self.dataKeyMappings addEntriesFromDictionary:obj];
            }
            else{
                self.dataKeyMappings = [obj mutableCopy];
            }
        }
        
    }];
}

- (NSString*)modelPropertyNameForDataKey:(NSString *)key
{
    NSString *propName = nil;
    if ([key isEqualToString:self.dataIdKey])
    {
        propName = self.modelIdPropertyName;
    }
    else
    {
        propName = [self.dataKeyMappings objectForKey:key];
        
        if (nil == propName){
            
            // look for property name similar to key/keypath, if found, cache it
            NSPredicate *propnamePred = [NSPredicate predicateWithFormat:@"SELF LIKE[cd] %@", key];
            NSArray *matches = [self.classPropertyNames filteredArrayUsingPredicate:propnamePred];
            if (matches.count > 0){
                propName = [matches objectAtIndex:0];
                [self.dataKeyMappings setObject:propName forKey:key];
            }
            
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

- (RZDataManagerModelObjectRelationshipMapping*)relationshipMappingForModelPropertyName:(NSString *)propName
{
    // for smaller collections enumeration is typically faster than predicate search
    __block RZDataManagerModelObjectRelationshipMapping *returnMapping = nil;
    
    [[self.relationshipKeyMappings allValues] enumerateObjectsUsingBlock:^(RZDataManagerModelObjectRelationshipMapping * mapping, NSUInteger idx, BOOL *stop) {
        if ([mapping.relationshipPropertyName isEqualToString:propName]){
            returnMapping = mapping;
            *stop = YES;
        }
    }];

    return returnMapping;
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
    self.dataIdKey = [[self.modelClass class] dataImportDefaultDataIdKey];
    self.modelIdPropertyName = [[self.modelClass class] dataImportModelIdPropertyName];
    
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

+ (RZDataManagerModelObjectRelationshipMapping*)mappingWithObjectType:(NSString *)type propertyName:(NSString *)propertyName inversePropertyName:(NSString *)inverse
{
    RZDataManagerModelObjectRelationshipMapping *mapping = [[RZDataManagerModelObjectRelationshipMapping alloc] init];
    mapping.relationshipObjectType = type;
    mapping.relationshipPropertyName = propertyName;
    mapping.relationshipInversePropertyName = inverse;
    return mapping;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [RZDataManagerModelObjectRelationshipMapping mappingWithObjectType:self.relationshipObjectType propertyName:self.relationshipPropertyName inversePropertyName:self.relationshipInversePropertyName];
}

@end
