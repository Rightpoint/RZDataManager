//
//  RZDataManager_Base.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/28/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataManager_Base.h"

NSString * const RZDataManagerCustomMappingKey = @"RZDataManagerCustomMapping";
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

- (id)objectOfType:(NSString*)type withValue:(id)value forKeyPath:(NSString*)keyPath createNew:(BOOL)createNew
{
    @throw [self abstractMethodException:_cmd];
}

- (id)objectOfType:(NSString*)type
         withValue:(id)value
        forKeyPath:(NSString*)keyPath
      inCollection:(id)collection
         createNew:(BOOL)createNew
{
    @throw [self abstractMethodException:_cmd];
}

- (id)objectsOfType:(NSString*)type matchingPredicate:(NSPredicate*)predicate
{
    @throw [self abstractMethodException:_cmd];
}

- (void)importData:(id)data objectType:(NSString*)type
           options:(NSDictionary *)options
        completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}


- (void)importData:(id)data objectType:(NSString *)type
   forRelationship:(NSString *)relationshipKey
          onObject:(id)otherObject
           options:(NSDictionary *)options
        completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}

- (void)importData:(id)data objectType:(NSString *)type
     dataIdKeyPath:(NSString *)dataIdKeyPath
    modelIdKeyPath:(NSString *)modelIdKeyPath
   forRelationship:(NSString *)relationshipKey
          onObject:(id)otherObject
        completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}

- (void)importInBackgroundUsingBlock:(RZDataManagerImportBlock)importBlock completion:(void (^)(NSError *))completionBlock
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

@end
