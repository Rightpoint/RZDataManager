//
//  RZDataManager_Base.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/28/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RZDataImporter.h"

// ---- Option keys for RZDataManager option dicts -----

OBJC_EXTERN NSString * const RZDataManagerDataIdKey;
OBJC_EXTERN NSString * const RZDataManagerModelIdKey;
OBJC_EXTERN NSString * const RZDataManagerShouldBreakRelationships; // needs a better name - if true, will break any cached relationships not present in imported data

typedef void (^RZDataManagerImportCompletionBlock)(id result, NSError * error); // result is either object, array, or nil

// This is an ABSTRACT BASE CLASS and should not be used directly. Use one of the provided concrete subclasses or create your own.

@interface RZDataManager : NSObject

// Singleton accessor that will work for subclasses.
+ (instancetype)defaultManager;

@property (nonatomic, readonly, strong) RZDataImporter *dataImporter;

// Directory helpers
- (NSURL*)applicationDocumentsDirectory;

// -------- SUBCLASSES MUST IMPLEMENT THESE METHODS -----------

#pragma mark - Fetching

// Catch-all method for retrieving an individual object
// "type" represents either class name as string or entity name for managed objects
- (id)objectOfType:(NSString*)type
         withValue:(id)value
        forKeyPath:(NSString*)keyPath
         createNew:(BOOL)createNew
           options:(NSDictionary*)options;

- (id)objectOfType:(NSString*)type
         withValue:(id)value
        forKeyPath:(NSString*)keyPath
             inSet:(NSSet*)objects
         createNew:(BOOL)createNew
           options:(NSDictionary*)options;

- (NSArray*)objectsOfType:(NSString*)type
        matchingPredicate:(NSPredicate*)predicate
                  options:(NSDictionary*)options;

#pragma mark - Persisting

// Either updates existing object(s), if any, or creates and inserts new object.
// "data" expected to be either NSDictionary or NSArray
- (void)importData:(id)data
        objectType:(NSString*)type
           options:(NSDictionary*)options
        completion:(RZDataManagerImportCompletionBlock)completion;

// Updates existing object or creates new, then attempts to create relationship with "otherObject" specified by "relationshipKey"
- (void)importData:(id)data
        objectType:(NSString *)type
   forRelationship:(NSString*)relationshipKey
          onObject:(id)otherObject
           options:(NSDictionary*)options
        completion:(RZDataManagerImportCompletionBlock)completion;

// Update an array of objects with a new array of dictionaries, representing objects of the same type.
// Will update, insert, remove, and re-order objects as necessary.
- (void)updateObjects:(NSArray*)objects
               ofType:(NSString*)type
             withData:(NSArray*)data
              options:(NSDictionary*)options
           completion:(RZDataManagerImportCompletionBlock)completion;


// -------------------------------------------------------------

// Save method. Not all subclasses may need to be explicitly saved/persisted, so this is optional.
- (void)saveData:(BOOL)synchronous;



#pragma mark - Utilities

- (NSString*)dataIdKeyForObjectType:(NSString*)type withOptions:(NSDictionary*)options;
- (NSString*)modelIdKeyForObjectType:(NSString*)type withOptions:(NSDictionary*)options;

@end
