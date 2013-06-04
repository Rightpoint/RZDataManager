//
//  RZDataManager_Base.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/28/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataManager_Base.h"

NSString * const RZDataManagerDataIdKey = @"RZDataManagerDataIdKey";
NSString * const RZDataManagerModelIdKey = @"RZDataManagerModelIdKey";
NSString * const RZDataManagerShouldBreakRelationships = @"RZDataManagerShouldBreakRelationships";

@interface RZDataManager ()

- (NSException*)abstractMethodException:(SEL)selector;
- (NSException*)missingUniqueKeysExceptionWithObjectType:(NSString*)objectType;

@end

@implementation RZDataManager
{
    RZDataImporter * _dataImporter;
}

+ (instancetype)defaultManager
{
    static RZDataManager * s_defaultManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_defaultManager = [[self alloc] init];
    });
    return s_defaultManager;
}

// Allocate data importer via lazy load
- (RZDataImporter*)dataImporter
{
    if (nil == _dataImporter){
        _dataImporter = [[RZDataImporter alloc] init];
        _dataImporter.dataManager = self;
    }
    return _dataImporter;
}

- (NSURL*)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSException*)abstractMethodException:(SEL)selector
{
    return [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(selector)]
                                 userInfo:nil];
}

- (NSException*)missingUniqueKeysExceptionWithObjectType:(NSString *)objectType
{
    return [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"Unable to find default ID key path in mapping for object type %@. Add \"Default ID Key\" to the mapping plist file", objectType]
                                 userInfo:nil];
}


#pragma mark - Data Manager public methods

- (id)objectOfType:(NSString*)type withValue:(id)value forKeyPath:(NSString*)keyPath createNew:(BOOL)createNew options:(NSDictionary *)options
{
    @throw [self abstractMethodException:_cmd];
}

- (id)objectsOfType:(NSString*)type matchingPredicate:(NSPredicate*)predicate options:(NSDictionary *)options
{
    @throw [self abstractMethodException:_cmd];
}

- (void)importData:(id)data objectType:(NSString*)type options:(NSDictionary *)options completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}


- (void)importData:(id)data objectType:(NSString *)type forRelationship:(NSString *)relationshipKey onObject:(id)otherObject options:(NSDictionary *)options completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}

- (void)importData:(id)data objectType:(NSString *)type dataIdKeyPath:(NSString *)dataIdKeyPath modelIdKeyPath:(NSString *)modelIdKeyPath forRelationship:(NSString *)relationshipKey onObject:(id)otherObject completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}

- (void)importInBackgroundUsingBlock:(RZDataManagerImportBlock)importBlock completion:(void (^)(NSError *))completionBlock
{
    @throw [self abstractMethodException:_cmd];
}

// optional, default does nothing
- (void)saveData:(BOOL)synchronous {}
- (void)discardChanges {}

#pragma mark - Utilities

- (NSString*)dataIdKeyForObjectType:(NSString *)type withOptions:(NSDictionary *)options
{
    NSString *dataIdKey = [options objectForKey:RZDataManagerDataIdKey];
    if (dataIdKey == nil){
        dataIdKey = [[self.dataImporter mappingForClassNamed:type] dataIdKey];
    }
    return dataIdKey;
}

- (NSString*)modelIdKeyForObjectType:(NSString*)type withOptions:(NSDictionary*)options
{
    NSString *modelIdKey = [options objectForKey:RZDataManagerModelIdKey];
    if (modelIdKey == nil){
        modelIdKey = [[self.dataImporter mappingForClassNamed:type] modelIdPropertyName];
    }
    return modelIdKey;
}

@end
