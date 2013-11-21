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

#define RZDataManagerLogError(x, ...) NSLog((@"[RZDataManager] ERROR: " x), ##__VA_ARGS__)

#if (DEBUG)
    #define RZDataManagerLogDebug(x, ...) NSLog((@"[RZDataManager] DEBUG: " x), ##__VA_ARGS__)
#else
    #define RZDataManagerLogDebug(x, ...)
#endif

typedef void (^RZDataManagerOperationBlock)(RZDataManager *manager, id context); // context object depends on particular subclass
typedef void (^RZDataManagerImportCompletionBlock)(id result, NSError *error); // result is either object, collection, or nil
typedef void (^RZDataManagerBackgroundOperationCompletionBlock)(NSError *error);

// Exception domain
OBJC_EXTERN NSString *const kRZDataManagerException;

// Standard ISO 8601 UTC string date format
OBJC_EXTERN NSString *const kRZDataManagerUTCDateFormat;

// ============================================================
//                KEYS FOR OPTIONS DICTIONARY
// ============================================================

// Delete any items from the database of that are not present in the import data.
// Effectively "replaces" all existing items of the type being imported with the items being imported.
// Default value is NO
OBJC_EXTERN NSString *const RZDataManagerReplaceItemsOptionKey;

// Delete any items that are present in the result produced by this predicate and not
// present in the items to be imported.
OBJC_EXTERN NSString *const RZDataManagerDeleteStaleItemsPredicateOptionKey;

// Perform automatic full-stack save of database after each import.
// Useful when you might want to undo an import.
// Default value is YES
OBJC_EXTERN NSString *const RZDataManagerSaveAfterImportOptionKey;

// Disable completion block from returning imported items on main thread managed object context.
// May want to use this to prevent resource usage when importing a large number of objects.
// Default value is NO
OBJC_EXTERN NSString *const RZDataManagerReturnObjectsFromImportOptionKey;

// If specified, adds extra attributes provided in NSDictionary value to be imported along with the
// "dictionaryOrArray" argument (if array, adds to each dictionary in the array). If the imported item
// already contains any of the keys in the additional data, they will be overwritten.
OBJC_EXTERN NSString *const RZDataManagerAdditionalImportDataOptionKey;

@interface RZDataManager : NSObject

// Singleton accessor will correctly cast return type for subclasses.
+ (instancetype)defaultManager;

#pragma mark - Utilities

+ (NSURL *)applicationDocumentsDirectory;

// pass through to data importer
- (RZDataManagerModelObjectMapping *)mappingForClassNamed:(NSString *)className;

@property (nonatomic, readonly, strong) RZDataImporter *dataImporter;


#pragma mark - Fetching

/***********************************************************
 *
 * Fetching objects from the data store by key/value pair.
 * "type" refers to the class name or entity type name
 *
 ***********************************************************/

// ============================================================
//          SUBCLASSES MUST IMPLEMENT THESE METHODS             
// ============================================================

// Returns an object with value "value" for keypath "keyPath". If not found, will optionally create a new one.
- (id)objectOfType:(NSString *)type
         withValue:(id)value
        forKeyPath:(NSString *)keyPath
         createNew:(BOOL)createNew;

// Limit search to a specific collection (set or array)
- (id)objectOfType:(NSString *)type
         withValue:(id)value
        forKeyPath:(NSString *)keyPath
      inCollection:(id)collection
         createNew:(BOOL)createNew;

- (id)objectsOfType:(NSString *)type matchingPredicate:(NSPredicate *)predicate;

// -------------------------------------------------------------

#pragma mark - Persisting

/******************************************************************************
 *
 *  Either updates existing object(s), if any, or creates and inserts new object.
 *  "data" expected to be either NSDictionary or NSArray. Results of import
 *  should be returned in completion block.
 *
 ******************************************************************************/

// Default signature, no overrides
- (void)importData:(id)dictionaryOrArray
     forClassNamed:(NSString *)className
           options:(NSDictionary *)options
        completion:(RZDataManagerImportCompletionBlock)completion;

// Use key-value pairs in keyMappings to override key->property import mappings
- (void)importData:(id)dictionaryOrArray
     forClassNamed:(NSString *)className
       keyMappings:(NSDictionary *)keyMappings
           options:(NSDictionary *)options
        completion:(RZDataManagerImportCompletionBlock)completion;

/******************************************************************************
 *
 *  Updates existing object or creates new, then attempts to create
 *  relationship with "otherObject" specified by "relationshipKey".
 *  Results of import should be returned in completion block.
 *
 ******************************************************************************/

- (void)         importData:(id)dictionaryOrArray
forRelationshipPropertyName:(NSString *)relationshipProperty
                   onObject:(NSObject *)object
                    options:(NSDictionary *)options
                 completion:(RZDataManagerImportCompletionBlock)completion;

// ============================================================
// -------- SUBCLASSES MUST IMPLEMENT THESE METHODS -----------
// ============================================================

// Mapping can be nil, in which case subclass should use default mapping for this object type
- (void)importData:(id)dictionaryOrArray
     forClassNamed:(NSString *)className
      usingMapping:(RZDataManagerModelObjectMapping *)mapping
           options:(NSDictionary *)options
        completion:(RZDataManagerImportCompletionBlock)completion;

- (void)        importData:(id)dictionaryOrArray
forRelationshipWithMapping:(RZDataManagerModelObjectRelationshipMapping *)relationshipMapping
                  onObject:(NSObject *)object
                   options:(NSDictionary *)options
                completion:(RZDataManagerImportCompletionBlock)completion;

- (void)performDataOperationInBackgroundUsingBlock:(RZDataManagerOperationBlock)importBlock
                                        completion:(RZDataManagerBackgroundOperationCompletionBlock)completionBlock;

// -------------------------------------------------------------

// Save method. Not all subclasses may need to be explicitly saved/persisted, so this is optional.
- (void)saveData:(BOOL)synchronous;

// Discard changes. Not all subclasses may need to do this, so this is optional.
- (void)discardChanges;


#pragma mark - Miscellaneous

- (NSDictionary *)dictionaryFromModelObject:(NSObject *)object;

- (NSDictionary *)dictionaryFromModelObject:(NSObject *)object usingMapping:(RZDataManagerModelObjectMapping *)mapping;

@end


