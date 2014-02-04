//
//  RZDataManager_Base.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/28/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataManager_Base.h"
#import "NSObject+RZPropertyUtils.h"

NSString *const kRZDataManagerException     = @"RZDataManagerException";
NSString *const kRZDataManagerUTCDateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'";

NSString *const RZDataManagerReplaceItemsOptionKey              = @"RZDataManagerReplaceItemsOptionKey";
NSString *const RZDataManagerDeleteStaleItemsPredicateOptionKey = @"RZDataManagerDeleteStaleItemsPredicateOptionKey";
NSString *const RZDataManagerSaveAfterImportOptionKey           = @"RZDataManagerSaveAfterImportOptionKey";
NSString *const RZDataManagerReturnObjectsFromImportOptionKey   = @"RZDataManagerReturnObjectsFromImportOptionKey";
NSString *const RZDataManagerAdditionalImportDataOptionKey      = @"RZDataManagerAdditionalImportDataOptionKey";

@interface RZDataManager ()

- (NSException *)abstractMethodException:(SEL)selector;

- (void)addDefaultOptions:(NSDictionary* __autoreleasing *)options;
- (id)importDataByAddingAttributes:(id)additionalDataDict toImportData:(id)dataDictOrArray;

@end

@implementation RZDataManager
{
    RZDataImporter *_dataImporter;
}

+ (instancetype)defaultManager
{
    static RZDataManager *s_defaultManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        s_defaultManager = [[self alloc] init];
    });
    return s_defaultManager;
}

// Allocate data importer via lazy load
- (RZDataImporter *)dataImporter
{
    if (nil == _dataImporter)
    {
        _dataImporter = [[RZDataImporter alloc] init];
    }
    return _dataImporter;
}

+ (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (RZDataManagerModelObjectMapping *)mappingForClassNamed:(NSString *)className
{
    return [self.dataImporter mappingForClassNamed:className];
}

#pragma mark - Private

- (NSException *)abstractMethodException:(SEL)selector
{
    return [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(selector)]
                                 userInfo:nil];
}

- (void)addDefaultOptions:(NSDictionary *__autoreleasing *)options
{
    // add default key for save after import (defaults to yes)
    if (options)
    {
        if ([*options objectForKey:RZDataManagerSaveAfterImportOptionKey] == nil)
        {
            NSMutableDictionary *newOpts = *options == nil ? [NSMutableDictionary dictionary] : [*options mutableCopy];
            [newOpts setValue:@(YES) forKey:RZDataManagerSaveAfterImportOptionKey];
            *options = newOpts;
        }
    }
}

- (id)importDataByAddingAttributes:(id)additionalDataDict toImportData:(id)dataDictOrArray
{
    id newDictOrArray = dataDictOrArray;
    
    // this will catch nil
    if ([additionalDataDict isKindOfClass:[NSDictionary class]])
    {
        if ([dataDictOrArray isKindOfClass:[NSArray class]])
        {
            // add to each item
            NSMutableArray *newItems = [NSMutableArray arrayWithCapacity:[(NSArray*)dataDictOrArray count]];
            [(NSArray*)dataDictOrArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
            {
                if ([obj isKindOfClass:[NSDictionary class]])
                {
                    NSMutableDictionary *newItem = [NSMutableDictionary dictionaryWithDictionary:obj];
                    [newItem addEntriesFromDictionary:additionalDataDict];
                    [newItems addObject:newItem];
                }

            }];
            newDictOrArray = newItems;
        }
        else if ([dataDictOrArray isKindOfClass:[NSDictionary class]])
        {
            NSMutableDictionary *newItem = [NSMutableDictionary dictionaryWithDictionary:dataDictOrArray];
            [newItem addEntriesFromDictionary:additionalDataDict];
            newDictOrArray = newItem;
        }
    }
    
    return newDictOrArray;
}

#pragma mark - Public Methods

- (void)importData:(id)dictionaryOrArray
     forClassNamed:(NSString *)className
           options:(NSDictionary *)options
        completion:(RZDataManagerImportCompletionBlock)completion
{
    [self addDefaultOptions:&options];
    dictionaryOrArray = [self importDataByAddingAttributes:[options objectForKey:RZDataManagerAdditionalImportDataOptionKey] toImportData:dictionaryOrArray];
    [self importData:dictionaryOrArray forClassNamed:className usingMapping:nil options:options completion:completion];
}

- (void)importData:(id)dictionaryOrArray
     forClassNamed:(NSString *)className
       keyMappings:(NSDictionary *)keyMappings
           options:(NSDictionary *)options
        completion:(RZDataManagerImportCompletionBlock)completion
{
    RZDataManagerMutableModelObjectMapping *mapping = [[self.dataImporter mappingForClassNamed:className] mutableCopy];
    [mapping setModelPropertiesForKeyNames:keyMappings];
    
    [self addDefaultOptions:&options];
    dictionaryOrArray = [self importDataByAddingAttributes:[options objectForKey:RZDataManagerAdditionalImportDataOptionKey] toImportData:dictionaryOrArray];
    [self importData:dictionaryOrArray forClassNamed:className usingMapping:mapping options:options completion:completion];
}

- (void)         importData:(id)dictionaryOrArray
forRelationshipPropertyName:(NSString *)relationshipProperty
                   onObject:(NSObject *)object
                    options:(NSDictionary *)options
                 completion:(RZDataManagerImportCompletionBlock)completion
{
    RZDataManagerModelObjectMapping             *objMapping = [self.dataImporter mappingForClassNamed:NSStringFromClass([object class])];
    RZDataManagerModelObjectRelationshipMapping *relMapping = [objMapping relationshipMappingForModelPropertyName:relationshipProperty];
    
    [self addDefaultOptions:&options];
    dictionaryOrArray = [self importDataByAddingAttributes:[options objectForKey:RZDataManagerAdditionalImportDataOptionKey] toImportData:dictionaryOrArray];
    [self importData:dictionaryOrArray forRelationshipWithMapping:relMapping onObject:object options:options completion:completion];
}

#pragma mark - Abstract Public Methods (MUST IMPLEMENT IN SUBCLASS)

- (id)objectOfType:(NSString *)type withValue:(id)value forKeyPath:(NSString *)keyPath createNew:(BOOL)createNew
{
    @throw [self abstractMethodException:_cmd];
}

- (id)objectOfType:(NSString *)type
         withValue:(id)value
        forKeyPath:(NSString *)keyPath
      inCollection:(id)collection
         createNew:(BOOL)createNew
{
    @throw [self abstractMethodException:_cmd];
}

- (id)objectsOfType:(NSString *)type matchingPredicate:(NSPredicate *)predicate
{
    @throw [self abstractMethodException:_cmd];
}

- (void)importData:(id)dictionaryOrArray
     forClassNamed:(NSString *)className
      usingMapping:(RZDataManagerModelObjectMapping *)mapping
           options:(NSDictionary *)options
        completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}


- (void)        importData:(id)dictionaryOrArray
forRelationshipWithMapping:(RZDataManagerModelObjectRelationshipMapping *)relationshipMapping
                  onObject:(NSObject *)object
                   options:(NSDictionary *)options
                completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}


- (void)performDataOperationInBackgroundUsingBlock:(RZDataManagerOperationBlock)importBlock
                                        completion:(RZDataManagerBackgroundOperationCompletionBlock)completionBlock
{
    @throw [self abstractMethodException:_cmd];
}

// optional, default does nothing
- (void)saveData:(BOOL)synchronous
{
    NSLog(@"RZDataManager: saveData: is not implemented.");
}

- (void)discardChanges
{
    NSLog(@"RZDataManager: discardChanges is not implemented.");
}

#pragma mark - Miscellaneous

- (NSDictionary *)dictionaryFromModelObject:(NSObject *)object
{
    return [self dictionaryFromModelObject:object includingInheritedClasses:NO usingMapping:[self.dataImporter mappingForClassNamed:NSStringFromClass([object class])]];
}

- (NSDictionary *)dictionaryFromModelObject:(NSObject *)object includingInheritedClasses:(BOOL)includeInherited usingMapping:(RZDataManagerModelObjectMapping *)mapping
{

    NSArray             *propertyNames            = [[object class] rz_getPropertyNamesIncludingInheritedClasses:includeInherited];
    NSMutableDictionary *dictionaryRepresentation = [NSMutableDictionary dictionaryWithCapacity:propertyNames.count];

    [propertyNames enumerateObjectsUsingBlock:^(NSString *propName, NSUInteger idx, BOOL *stop)
    {

        NSString *propType = [[object class] rz_dataTypeForPropertyNamed:propName];

        if (rz_isScalarDataType(propType))
        {
            // TODO: For now this will only work if the getter name is not overridden. Need to handle that case in the future (in property utils).
            SEL getter = NSSelectorFromString(propName);

            NSNumber *numberValue = nil;

            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:getter]];
            [invocation setTarget:object];
            [invocation setSelector:getter];

            if ([propType isEqualToString:kRZDataTypeChar])
            {
                char charValue;
                [invocation invoke];
                [invocation getReturnValue:&charValue];
                numberValue = @(charValue);
            }
            else if ([propType isEqualToString:kRZDataTypeInt])
            {
                NSInteger intValue;
                [invocation invoke];
                [invocation getReturnValue:&intValue];
                numberValue = @(intValue);
            }
            else if ([propType isEqualToString:kRZDataTypeUnsignedInt])
            {
                NSUInteger uIntValue;
                [invocation invoke];
                [invocation getReturnValue:&uIntValue];
                numberValue = @(uIntValue);
            }
            else if ([propType isEqualToString:kRZDataTypeShort])
            {
                SInt16 shortValue;
                [invocation invoke];
                [invocation getReturnValue:&shortValue];
                numberValue = @(shortValue);
            }
            else if ([propType isEqualToString:kRZDataTypeUnsignedShort])
            {
                UInt16 uShortValue;
                [invocation invoke];
                [invocation getReturnValue:&uShortValue];
                numberValue = @(uShortValue);
            }
            else if ([propType isEqualToString:kRZDataTypeLong])
            {
                SInt32 longValue;
                [invocation invoke];
                [invocation getReturnValue:&longValue];
                numberValue = @(longValue);
            }
            else if ([propType isEqualToString:kRZDataTypeUnsignedLong])
            {
                UInt32 uLongValue;
                [invocation invoke];
                [invocation getReturnValue:&uLongValue];
                numberValue = @(uLongValue);
            }
            else if ([propType isEqualToString:kRZDataTypeLongLong])
            {
                SInt64 longLongValue;
                [invocation invoke];
                [invocation getReturnValue:&longLongValue];
                numberValue = @(longLongValue);
            }
            else if ([propType isEqualToString:kRZDataTypeUnsignedLongLong])
            {
                UInt64 uLongLongValue;
                [invocation invoke];
                [invocation getReturnValue:&uLongLongValue];
                numberValue = @(uLongLongValue);
            }
            else if ([propType isEqualToString:kRZDataTypeFloat])
            {
                float floatValue;
                [invocation invoke];
                [invocation getReturnValue:&floatValue];
                numberValue = @(floatValue);
            }
            else if ([propType isEqualToString:kRZDataTypeDouble])
            {
                double doubleValue;
                [invocation invoke];
                [invocation getReturnValue:&doubleValue];
                numberValue = @(doubleValue);
            }

            if (nil != numberValue)
            {
                [dictionaryRepresentation setObject:numberValue forKey:propName];
            }
        }
        else if ([mapping relationshipMappingForModelPropertyName:propName])
        {
            // for relationships, don't serialze the entire other object - this could lead to infinite recursion
            // just convert the unique identifier key/value pairs
            RZDataManagerModelObjectRelationshipMapping *relMapping      = [mapping relationshipMappingForModelPropertyName:propName];
            RZDataManagerModelObjectMapping             *otherObjMapping = [self.dataImporter mappingForClassNamed:relMapping.relationshipClassName];

            id propValue = nil;
            @try
            {
                propValue = [object valueForKey:propName];
            }
            @catch (NSException *exception)
            {
                NSLog(@"RZDataImporter: Object of type %@ does not respond to key %@", NSStringFromClass([object class]), propName);
            }

            id (^IdSerializerBlock)(id obj) = ^id(id obj)
            {

                id otherObjUid = nil;
                @try
                {
                    otherObjUid = [obj valueForKey:otherObjMapping.modelIdPropertyName];
                }
                @catch (NSException *exception)
                {
                    NSLog(@"RZDataImporter: Object of type %@ does not respond to key %@", relMapping.relationshipClassName, otherObjMapping.modelIdPropertyName);
                }

                return otherObjUid;

            };

            if ([propValue isKindOfClass:[NSArray class]])
            {
                NSMutableArray *relArray = [NSMutableArray arrayWithCapacity:[propValue count]];
                [(NSArray *)propValue enumerateObjectsUsingBlock:^(id obj, NSUInteger arrIdx, BOOL *arrStop)
                {

                    id otherObjUid = IdSerializerBlock(obj);

                    if (otherObjUid)
                    {
                        [relArray addObject:@{otherObjMapping.dataIdKey : otherObjUid}];
                    }

                }];

                [dictionaryRepresentation setObject:relArray forKey:propName];
            }
            else if ([propValue isKindOfClass:[NSSet class]])
            {
                NSMutableSet *relSet = [NSMutableSet setWithCapacity:[propValue count]];
                [(NSSet *)propValue enumerateObjectsUsingBlock:^(id obj, BOOL *stop)
                {
                    id otherObjUid = IdSerializerBlock(obj);

                    if (otherObjUid)
                    {
                        [relSet addObject:@{otherObjMapping.dataIdKey : otherObjUid}];
                    }

                }];

                [dictionaryRepresentation setObject:relSet forKey:propName];

            }
            else if (propValue != nil)
            {
                id otherObjUid = IdSerializerBlock(propValue);

                if (otherObjUid)
                {
                    [dictionaryRepresentation setObject:@{otherObjMapping.dataIdKey : otherObjUid} forKey:propName];
                }
            }
        }
        else
        {
            id propValue = nil;
            @try
            {
                propValue = [object valueForKey:propName];
            }
            @catch (NSException *exception)
            {
                NSLog(@"RZDataImporter: Object of type %@ does not respond to key %@", NSStringFromClass([object class]), propName);
            }
            if (propValue)
            {
                [dictionaryRepresentation setObject:propValue forKey:propName];
            }
        }

    }];

    return dictionaryRepresentation;
}

@end
