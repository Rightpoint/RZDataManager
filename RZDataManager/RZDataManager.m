//
//  RZDataManager.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/28/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataManager.h"

@interface RZDataManager ()

- (NSException*)abstractMethodException:(SEL)selector;

@end

@implementation RZDataManager
{
    RZDataImporter * _dataImporter;
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

// All required data management methods must be subclassed

- (id)objectOfType:(NSString*)type withValue:(id)value forKeyPath:(NSString*)keyPath createNew:(BOOL)createNew
{
    @throw [self abstractMethodException:_cmd];
}

- (id)objectOfType:(NSString*)type withValue:(id)value forKeyPath:(NSString*)keyPath inSet:(NSSet*)objects createNew:(BOOL)createNew
{
    @throw [self abstractMethodException:_cmd];
}

- (NSArray*)objectsOfType:(NSString*)type matchingPredicate:(NSPredicate*)predicate
{
    @throw [self abstractMethodException:_cmd];
}

- (void)importData:(NSDictionary*)data toObjectOfType:(NSString*)type dataIdKeyPath:(NSString*)dataIdKeyPath modelIdKeyPath:(NSString*)modelIdKeyPath completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}

- (void)updateObjects:(NSArray*)objects ofType:(NSString*)type withData:(NSArray*)data dataIdKeyPath:(NSString*)dataIdKeyPath modelIdKeyPath:(NSString*)modelIdKeyPath completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}

// optional, default does nothing
- (void)saveData:(BOOL)synchronous { }

@end
