//
//  RZDataManager.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/28/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RZDataImporter.h"

typedef void (^RZDataManagerImportCompletionBlock)(id result, NSError * error); // result is either object, array, or nil

// This is an ABSTRACT BASE CLASS and should not be used directly. Use one of the provided concrete subclasses or create your own.

@interface RZDataManager : NSObject

// Singleton accessor that will work for subclasses.
+ (instancetype)defaultManager;

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

// Either updates existing object, if any, or creates and inserts new object
- (void)importData:(NSDictionary*)data toObjectOfType:(NSString*)type dataIdKeyPath:(NSString*)dataIdKeyPath modelIdKeyPath:(NSString*)modelIdKeyPath completion:(RZDataManagerImportCompletionBlock)completion;

// Updates existing object or creates new, then attempts to create relationship with "otherObject" specified by "relationshipKey"
- (void)importData:(NSDictionary *)data toObjectOfType:(NSString *)type dataIdKeyPath:(NSString *)dataIdKeyPath modelIdKeyPath:(NSString *)modelIdKeyPath forRelationship:(NSString*)relationshipKey onObject:(id)otherObject completion:(RZDataManagerImportCompletionBlock)completion;

- (void)updateObjects:(NSArray*)objects ofType:(NSString*)type withData:(NSArray*)data dataIdKeyPath:(NSString*)dataIdKeyPath modelIdKeyPath:(NSString*)modelIdKeyPath completion:(RZDataManagerImportCompletionBlock)completion;

// Save method. Not all subclasses may need to be explicitly saved/persisted, so this is optional.
- (void)saveData:(BOOL)synchronous;

@end
