//
//  RZCoreDataManager.h
//
//  Created by Joe Goullaud on 2/12/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "RZDataManager_Base.h"

/*************************************************************************************
 *
 * Concrete RZDataManager subclass for working with a CoreData stack.
 *
 * Things to know:
 *
 * 1) If you do not explicitly set the context, model, or store coordinator, they will
 *    be built automatically when first accessed.
 *
 * 2) Performing an import DOES NOT SAVE to the persistent store! This allows "undo" of 
 *    all changes to objects since the last save (using discardChanges:).
 *
 * 3) On that note, calling save on the public MOC will NOT persist to disk! Use
 *    RZDataManager's saveData: instead.
 *
 * 4) importInBackgroundUsingBlock: can be used to perform any managed object graph
 *    or object modifications on a background thread, not just imports.
 *
 ************************************************************************************/


OBJC_EXTERN NSString * const kRZCoreDataManagerWillResetDatabaseNotification;
OBJC_EXTERN NSString * const kRZCoreDataManagerDidResetDatabaseNotification;

// ============================================================
//                KEYS FOR OPTIONS DICTIONARY
// ============================================================

// If value is YES, will perform background import on its own thread, independent and parallel to other background imports
// This is useful when importing large amounts of data that doesn't affect other imports and may otherwise hold up the queue
OBJC_EXTERN NSString * const kRZCoreDataManagerImportAsynchronously;


@class RZDataImporter;

@interface RZCoreDataManager : RZDataManager

//! Provide a model file name here without an extension BEFORE ACCESSING THE STACK. If left nil, will default to bundle display name.
@property (nonatomic, strong) NSString *managedObjectModelName;

//! Set the persistent store type BEFORE ACCESSING THE STACK. Defaults to NSInMemoryStoreType.
@property (nonatomic, strong) NSString *persistentStoreType;

//! Set the persistent store URL BEFORE ACCESSING THE STACK. Only used with disk-backed store coordinators. Defaults to /<YourApp>/Documents/<ModelName>.sqlite
@property (nonatomic, strong) NSURL *persistentStoreURL;

//! Main-thread accessible MOC. Saving this MOC does NOT persist to disk. Use saveData: instead.
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

// If synchronously is true, will queue imports using a private dispatch queue to happen on background, but serially.
// If false, will perform import on private queue confinement moc, parallel to any other import operations
- (void)importInBackgroundSynchronously:(BOOL)synchronously usingBlock:(RZDataManagerImportBlock)importBlock completion:(RZDataManagerBackgroundImportCompletionBlock)completionBlock;

//! Clears out CoreData stack and posts reset notifications. Will be rebuilt via lazy-load on next access to the MOC.
- (void)resetDatabase;

@end
