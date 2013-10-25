//
//  RZDataImporterMapping.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataManagerModelObjectMapping.h"
#import "RZDataManagerModelObject.h"
#import "RZDataManager_Base.h"
#import "NSObject+RZPropertyUtils.h"
#import "RZLogHelper.h"

@interface RZDataManagerModelObjectMapping ()

@property (nonatomic, assign) Class modelClass;
@property (nonatomic, strong) NSArray             *classPropertyNames;
@property (nonatomic, strong) NSMutableArray      *ignoreKeys;
@property (nonatomic, strong) NSMutableDictionary *dataKeyMappings;
@property (nonatomic, strong) NSMutableDictionary *relationshipKeyMappings;
@property (nonatomic, strong) NSMutableDictionary *customSelectorKeyMappings;

- (void)buildMappingCache;

@end

@implementation RZDataManagerModelObjectMapping

- (id)initWithModelClass:(Class)modelClass
{
    self = [super init];
    if (self)
    {
        self.modelClass = modelClass;
        [self buildMappingCache];
    }
    return self;
}

#pragma mark - Properties

// lazy load these

- (NSMutableDictionary *)dataKeyMappings
{
    if (nil == _dataKeyMappings)
    {
        _dataKeyMappings = [NSMutableDictionary dictionary];
    }
    return _dataKeyMappings;
}

- (NSMutableDictionary *)relationshipKeyMappings
{
    if (nil == _relationshipKeyMappings)
    {
        _relationshipKeyMappings = [NSMutableDictionary dictionary];
    }
    return _relationshipKeyMappings;
}

- (NSMutableDictionary *)customSelectorKeyMappings
{
    if (nil == _customSelectorKeyMappings)
    {
        _customSelectorKeyMappings = [NSMutableDictionary dictionary];
    }
    return _customSelectorKeyMappings;
}

- (NSMutableArray *)ignoreKeys
{
    if (nil == _ignoreKeys)
    {
        _ignoreKeys = [NSMutableArray array];
    }
    return _ignoreKeys;
}

#pragma mark - Public

- (BOOL)hasMappingDefinedForDataKey:(NSString *)key
{
    return ([self modelPropertyNameForDataKey:key] != nil ||
            [self relationshipMappingForDataKey:key] != nil ||
            [self importSelectorNameForDataKey:key] != nil);
}

- (NSString *)modelPropertyNameForDataKey:(NSString *)key
{
    NSString *propName = nil;
    if ([key isEqualToString:self.dataIdKey])
    {
        propName = self.modelIdPropertyName;
    }
    else if (![self.ignoreKeys containsObject:key])
    {
        propName = [self.dataKeyMappings objectForKey:key];

        if (nil == propName)
        {

            // look for property name similar to key/keypath, if found, cache it
            NSPredicate *propnamePred = [NSPredicate predicateWithFormat:@"SELF LIKE[cd] %@", key];
            NSArray     *matches      = [self.classPropertyNames filteredArrayUsingPredicate:propnamePred];
            if (matches.count > 0)
            {
                propName = [matches objectAtIndex:0];
                [self.dataKeyMappings setObject:propName forKey:key];
            }
            else
            {
                RZLogDebug(@"Could not find matching property for key %@ on object of type %@", key, NSStringFromClass([self modelClass]));
                [self.ignoreKeys addObject:key];
            }

        }
    }


    return propName;
}

- (NSDictionary *)allRelationshipMappings
{
    return [self.relationshipKeyMappings copy];
}

- (RZDataManagerModelObjectRelationshipMapping *)relationshipMappingForDataKey:(NSString *)key
{
    return [self.relationshipKeyMappings objectForKey:key];
}

- (RZDataManagerModelObjectRelationshipMapping *)relationshipMappingForModelPropertyName:(NSString *)propName
{
    // for smaller collections enumeration is typically faster than predicate search
    __block RZDataManagerModelObjectRelationshipMapping *returnMapping = nil;

    [[self.relationshipKeyMappings allValues] enumerateObjectsUsingBlock:^(RZDataManagerModelObjectRelationshipMapping *mapping, NSUInteger idx, BOOL *stop)
    {
        if ([mapping.relationshipPropertyName isEqualToString:propName])
        {
            returnMapping = mapping;
            *stop = YES;
        }
    }];

    return returnMapping;
}

- (NSString *)importSelectorNameForDataKey:(NSString *)key
{
    return [self.customSelectorKeyMappings objectForKey:key];
}

- (NSArray *)keysToIgnore
{
    return [self.ignoreKeys copy];
}

#pragma mark - Private

- (void)buildMappingCache
{
    if (![self.modelClass conformsToProtocol:@protocol(RZDataManagerModelObject)])
    {
        @throw [NSException exceptionWithName:kRZDataManagerException reason:@"Object does not conform to RZDataManagerModelObject protocol" userInfo:nil];
    }
    
    _classPropertyNames  = [[[self.modelClass class] rz_getPropertyNames] copy];
    _dataIdKey           = [[[self.modelClass class] dataImportDefaultDataIdKey] copy];
    _modelIdPropertyName = [[[self.modelClass class] dataImportModelIdPropertyName] copy];

    if ([[self.modelClass class] respondsToSelector:@selector(dataImportDateFormat)])
    {
        _dateFormat = [[self.modelClass class] dataImportDateFormat];
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
    // It's immutable, so we can just return the same object
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    RZDataManagerMutableModelObjectMapping *mapping = [[RZDataManagerMutableModelObjectMapping allocWithZone:zone] init];
    
    mapping.dataIdKey                 = self.dataIdKey;
    mapping.modelIdPropertyName       = self.modelIdPropertyName;
    mapping.dateFormat                = self.dateFormat;
    mapping.ignoreKeys                = [self.ignoreKeys mutableCopy];
    mapping.modelClass                = self.modelClass;
    mapping.classPropertyNames        = [self.classPropertyNames copy];
    mapping.dataKeyMappings           = [self.dataKeyMappings mutableCopy];
    mapping.customSelectorKeyMappings = [self.customSelectorKeyMappings mutableCopy];
    
    // deep copy relationship key mappings
    mapping.relationshipKeyMappings = [[NSMutableDictionary alloc] initWithDictionary:self.relationshipKeyMappings copyItems:YES];
    
    return mapping;
}

@end

@implementation RZDataManagerMutableModelObjectMapping

@synthesize dataIdKey;
@synthesize modelIdPropertyName;
@synthesize dateFormat;

- (void)setModelPropertyName:(NSString *)propertyName forDataKey:(NSString *)key
{
    [self.dataKeyMappings setObject:propertyName forKey:key];
}

- (void)setModelPropertiesForKeyNames:(NSDictionary *)mappingDict
{
    [self.dataKeyMappings addEntriesFromDictionary:mappingDict];
}

- (void)setRelationshipMapping:(RZDataManagerModelObjectRelationshipMapping *)mapping forDataKey:(NSString *)key
{
    [self.relationshipKeyMappings setObject:mapping forKey:key];
}

- (void)setImportSelectorName:(NSString *)selName forDataKey:(NSString *)key
{
    [self.customSelectorKeyMappings setObject:selName forKey:key];
}
- (void)addKeysToIgnore:(NSArray *)keysToIgnore
{
    [self.ignoreKeys addObjectsFromArray:keysToIgnore];
}

@end

#pragma mark - Relationship Mappings


@implementation RZDataManagerModelObjectRelationshipMapping

+ (instancetype)mappingWithClassNamed:(NSString *)type
                         propertyName:(NSString *)propertyName
                  inversePropertyName:(NSString *)inverse
{
   return [[self alloc] initWithClassNamed:type
                              propertyName:propertyName
                       inversePropertyName:inverse];
}

- (id)initWithClassNamed:(NSString *)type propertyName:(NSString *)propertyName inversePropertyName:(NSString *)inverse
{
    if ((self = [super init]))
    {
        _relationshipClassName           = [type copy];
        _relationshipPropertyName        = [propertyName copy];
        _relationshipInversePropertyName = [inverse copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    // It's immutable, so we can just return the same object
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    RZDataManagerMutableModelObjectRelationshipMapping *copy = [[RZDataManagerMutableModelObjectRelationshipMapping allocWithZone:zone] initWithClassNamed:self.relationshipClassName
                                                                                                                                              propertyName:self.relationshipPropertyName
                                                                                                                                       inversePropertyName:self.relationshipInversePropertyName];
    copy.shouldReplaceExistingRelationships = self.shouldReplaceExistingRelationships;
    copy.relatedObjectMapping               = [self.relatedObjectMapping copy];
    return copy;
}


@end

@implementation RZDataManagerMutableModelObjectRelationshipMapping

@synthesize shouldReplaceExistingRelationships;
@synthesize relatedObjectMapping;

@end
