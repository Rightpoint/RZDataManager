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
@property (nonatomic, strong) NSMutableArray  *ignoreKeys;
@property (nonatomic, strong) NSMutableDictionary *dataKeyMappings;
@property (nonatomic, strong) NSMutableDictionary *relationshipKeyMappings;
@property (nonatomic, strong) NSMutableDictionary *customSelectorKeyMappings;

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

#pragma mark - Properties

// lazy load these

- (NSMutableDictionary*)dataKeyMappings
{
    if (nil == _dataKeyMappings){
        _dataKeyMappings = [NSMutableDictionary dictionary];
    }
    return _dataKeyMappings;
}

- (NSMutableDictionary*)relationshipKeyMappings
{
    if (nil == _relationshipKeyMappings){
        _relationshipKeyMappings = [NSMutableDictionary dictionary];
    }
    return _relationshipKeyMappings;
}

- (NSMutableDictionary*)customSelectorKeyMappings
{
    if (nil == _customSelectorKeyMappings){
        _customSelectorKeyMappings = [NSMutableDictionary dictionary];
    }
    return _customSelectorKeyMappings;
}

- (NSMutableArray*)ignoreKeys
{
    if (nil == _ignoreKeys){
        _ignoreKeys = [NSMutableArray array];
    }
    return _ignoreKeys;
}

#pragma mark - Public


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
    [self.dataKeyMappings setObject:propertyName forKey:key];
}

- (void)setModelPropertiesForKeyNames:(NSDictionary *)mappingDict
{
    [self.dataKeyMappings addEntriesFromDictionary:mappingDict];
}

- (RZDataManagerModelObjectRelationshipMapping*)relationshipMappingForDataKey:(NSString *)key
{
    return [[self.relationshipKeyMappings objectForKey:key] copy];
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

    return [returnMapping copy];
}

- (void)setRelationshipMapping:(RZDataManagerModelObjectRelationshipMapping *)mapping forDataKey:(NSString *)key
{
    [self.relationshipKeyMappings setObject:[mapping copy] forKey:key];
}

- (NSString*)importSelectorNameForDataKey:(NSString*)key
{
    return [self.customSelectorKeyMappings objectForKey:key];
}

- (void)setImportSelectorName:(NSString*)selName forDataKey:(NSString*)key
{
    [self.customSelectorKeyMappings setObject:selName forKey:key];
}

- (NSArray*)keysToIgnore
{
    return [self.ignoreKeys copy];
}

- (void)addKeysToIgnore:(NSArray *)keysToIgnore
{
    [self.ignoreKeys addObjectsFromArray:keysToIgnore];
}

#pragma mark - Private

- (void)buildMappingCache
{
    self.classPropertyNames = [[self.modelClass class] rz_getPropertyNames];
    self.dataIdKey = [[self.modelClass class] dataImportDefaultDataIdKey];
    self.modelIdPropertyName = [[self.modelClass class] dataImportModelIdPropertyName];
    
    if ([[self.modelClass class] respondsToSelector:@selector(dataImportDateFormat)])
    {
        self.dateFormat = [[self.modelClass class] dataImportDateFormat];
    }
    
    if ([[self.modelClass class] respondsToSelector:@selector(dataImportIgnoreKeys)])
    {
        self.ignoreKeys = [[[self.modelClass class] dataImportIgnoreKeys] mutableCopy];
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
    mapping.ignoreKeys = [self.ignoreKeys mutableCopy];
    mapping.modelClass = self.modelClass;
    mapping.classPropertyNames = [self.classPropertyNames copy];
    mapping.dataKeyMappings = [self.dataKeyMappings mutableCopy];
    mapping.customSelectorKeyMappings = [self.customSelectorKeyMappings mutableCopy];
    
    // deep copy relationship key mappings
    mapping.relationshipKeyMappings = [[NSMutableDictionary alloc] initWithDictionary:self.relationshipKeyMappings copyItems:YES];
    
    return mapping;
}

@end

@implementation RZDataManagerModelObjectRelationshipMapping

+ (RZDataManagerModelObjectRelationshipMapping*)mappingWithClassNamed:(NSString *)type propertyName:(NSString *)propertyName inversePropertyName:(NSString *)inverse
{
    RZDataManagerModelObjectRelationshipMapping *mapping = [[RZDataManagerModelObjectRelationshipMapping alloc] init];
    mapping.relationshipClassName = type;
    mapping.relationshipPropertyName = propertyName;
    mapping.relationshipInversePropertyName = inverse;
    return mapping;
}

- (id)copyWithZone:(NSZone *)zone
{
    RZDataManagerModelObjectRelationshipMapping *copy = [RZDataManagerModelObjectRelationshipMapping mappingWithClassNamed:self.relationshipClassName
                                                                                                              propertyName:self.relationshipPropertyName
                                                                                                       inversePropertyName:self.relationshipInversePropertyName];
    copy.shouldReplaceExistingRelationships = self.shouldReplaceExistingRelationships;
    copy.relatedObjectMapping = [self.relatedObjectMapping copy];
    return copy;
}

@end
