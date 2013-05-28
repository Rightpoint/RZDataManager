//
//  RZDataManager.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/28/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RZDataImporter.h"

typedef void (^RZDataManagerCompletionBlock)();
typedef void (^RZDataManagerImportBlock)();

// This is an ABSTRACT BASE CLASS and should not be used directly. Use one of the provided concrete subclasses or create your own.
@interface RZDataManager : NSObject

@property (nonatomic, readonly, strong) RZDataImporter *dataImporter;

// Directory helpers
- (NSURL*)applicationDocumentsDirectory;

#pragma mark - Fetching

// Catch-all method for retrieving an individual object
// "type" represents either class name as string or entity name for managed objects
- (id)objectOfType:(NSString*)type withValue:(id)value forKeyPath:(NSString*)keyPath createNew:(BOOL)createNew;

- (id)objectOfType:(NSString*)type withValue:(id)value forKeyPath:(NSString*)keyPath inSet:(NSSet*)objects createNew:(BOOL)createNew;

- (NSArray*)objectsOfType:(NSString*)type matchingPredicate:(NSPredicate*)predicate;

#pragma mark - Persisting

- (void)importData:(NSDictionary*)data toObjectOfType:(NSString*)type dataIdKeyPath:(NSString*)dataIdKeyPath modelIdKeyPath:(NSString*)modelIdKeyPath completion:(RZDataManagerCompletionBlock)completion;

- (void)updateObjects:(NSArray*)objects ofType:(NSString*)type withData:(NSArray*)data dataIdKeyPath:(NSString*)dataIdKeyPath modelIdKeyPath:(NSString*)modelIdKeyPath completion:(RZDataManagerCompletionBlock)completion;

// Save method. Not all subclasses may need to be explicitly saved/persisted, so this is optional.
- (void)saveData:(BOOL)synchronous;

@end
