//
//  RZDataManager_Base.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/28/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

// =========================================================
//
// This is an ABSTRACT BASE CLASS and should not be used directly.
// Use one of the provided concrete subclasses or create your own.
//
// =========================================================


#import <Foundation/Foundation.h>
#import "RZDataImporter.h"

typedef void (^RZDataManagerImportBlock)();
typedef void (^RZDataManagerImportCompletionBlock)(id result, NSError * error); // result is either object, collection, or nil

@interface RZDataManager : NSObject

// Singleton accessor will correctly cast return type for subclasses.
+ (instancetype)defaultManager;

@property (nonatomic, readonly, strong) RZDataImporter *dataImporter;

- (NSURL*)applicationDocumentsDirectory;


#pragma mark - Fetching

// Fetching objects from the data store by key/value pair.
// "type" represents either class name as string or entity name for managed objects

// -------- SUBCLASSES MUST IMPLEMENT THESE METHODS -----------


- (id)objectOfType:(NSString*)type
         withValue:(id)value
        forKeyPath:(NSString*)keyPath
         createNew:(BOOL)createNew;

- (id)objectOfType:(NSString*)type
         withValue:(id)value
        forKeyPath:(NSString*)keyPath
      inCollection:(id)collection
         createNew:(BOOL)createNew;

- (id)objectsOfType:(NSString*)type matchingPredicate:(NSPredicate*)predicate;

// -------------------------------------------------------------

#pragma mark - Persisting

// -------- SUBCLASSES MUST IMPLEMENT THESE METHODS -----------

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

- (void)importInBackgroundUsingBlock:(RZDataManagerImportBlock)importBlock completion:(void(^)(NSError *error))completionBlock;

// -------------------------------------------------------------

// Save method. Not all subclasses may need to be explicitly saved/persisted, so this is optional.
- (void)saveData:(BOOL)synchronous;

// Discard changes. Not all subclasses may need to do this, so this is optional.
- (void)discardChanges;

@end

#pragma mark - RZDataManager option keys

OBJC_EXTERN NSString * const RZDataManagerCustomMappingKey; // provide a custom mapping (RZDataManagerModelObjectMapping) in the options dict
OBJC_EXTERN NSString * const RZDataManagerShouldBreakRelationships; // needs a better name - if true, will break any cached relationships not present in imported data

