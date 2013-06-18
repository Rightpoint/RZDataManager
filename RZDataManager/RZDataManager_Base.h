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

OBJC_EXTERN NSString* const kRZDataManagerUTCDateFormat;

typedef void (^RZDataManagerImportBlock)();
typedef void (^RZDataManagerImportCompletionBlock)(id result, NSError * error); // result is either object, collection, or nil
typedef void (^RZDataManagerBackgroundImportCompletionBlock)(NSError* error);

@interface RZDataManager : NSObject

// Singleton accessor will correctly cast return type for subclasses.
+ (instancetype)defaultManager;

#pragma mark - Utilities

+ (NSURL*)applicationDocumentsDirectory;

// pass through to data importer
- (RZDataManagerModelObjectMapping*)mappingForClassNamed:(NSString*)className;

@property (nonatomic, readonly, strong) RZDataImporter *dataImporter;


#pragma mark - Fetching

// Fetching objects from the data store by key/value pair.
// "type" represents either class name as string or entity name for managed objects

// -------- SUBCLASSES MUST IMPLEMENT THESE METHODS -----------

// Returns an object with value "value" for keypath "keyPath". If not found, will optionally create a new one.
- (id)objectOfType:(NSString*)type
         withValue:(id)value
        forKeyPath:(NSString*)keyPath
         createNew:(BOOL)createNew;

// Limit search to a specific collection (set or array)
- (id)objectOfType:(NSString*)type
         withValue:(id)value
        forKeyPath:(NSString*)keyPath
      inCollection:(id)collection
         createNew:(BOOL)createNew;

- (id)objectsOfType:(NSString*)type matchingPredicate:(NSPredicate*)predicate;

// -------------------------------------------------------------

#pragma mark - Persisting

/*
 *  Either updates existing object(s), if any, or creates and inserts new object.
 *  "data" expected to be either NSDictionary or NSArray. Results of import
 *  should be returned in completion block.
 */

// Default signature, no overrides
- (void)importData:(id)data
        objectType:(NSString*)type
           options:(NSDictionary*)options
        completion:(RZDataManagerImportCompletionBlock)completion;

// Use key-value pairs in keyMappings to override key->property import mappings
- (void)importData:(id)data
        objectType:(NSString*)type
       keyMappings:(NSDictionary*)keyMappings
           options:(NSDictionary*)options
        completion:(RZDataManagerImportCompletionBlock)completion;

/*
 *  Updates existing object or creates new, then attempts to create
 *  relationship with "otherObject" specified by "relationshipKey".
 *  Results of import should be returned in completion block.
 */

// Default signature, no overrides
- (void)importData:(id)data
        objectType:(NSString *)type
   forRelationship:(NSString*)relationshipKey
          onObject:(id)otherObject
           options:(NSDictionary*)options
        completion:(RZDataManagerImportCompletionBlock)completion;

// Use key-value pairs in keyMappings to override key->property import mappings
- (void)importData:(id)data
        objectType:(NSString *)type
   forRelationship:(NSString*)relationshipKey
          onObject:(id)otherObject
       keyMappings:(NSDictionary*)keyMappings
           options:(NSDictionary*)options
        completion:(RZDataManagerImportCompletionBlock)completion;


// -------- SUBCLASSES MUST IMPLEMENT THESE METHODS -----------

// Mapping can be nil, in which case subclass should use default mapping for this object type

- (void)importData:(id)data
        objectType:(NSString*)type
      usingMapping:(RZDataManagerModelObjectMapping*)mapping
           options:(NSDictionary*)options
        completion:(RZDataManagerImportCompletionBlock)completion;

- (void)importData:(id)data
        objectType:(NSString *)type
   forRelationship:(NSString*)relationshipKey
          onObject:(id)otherObject
      usingMapping:(RZDataManagerModelObjectMapping*)mapping
           options:(NSDictionary*)options
        completion:(RZDataManagerImportCompletionBlock)completion;

- (void)importInBackgroundUsingBlock:(RZDataManagerImportBlock)importBlock
                          completion:(RZDataManagerBackgroundImportCompletionBlock)completionBlock;

// -------------------------------------------------------------

// Save method. Not all subclasses may need to be explicitly saved/persisted, so this is optional.
- (void)saveData:(BOOL)synchronous;

// Discard changes. Not all subclasses may need to do this, so this is optional.
- (void)discardChanges;


#pragma mark - Miscellaneous

- (NSDictionary*)dictionaryFromModelObject:(NSObject*)object;
- (NSDictionary*)dictionaryFromModelObject:(NSObject*)object usingMapping:(RZDataManagerModelObjectMapping*)mapping;

@end


