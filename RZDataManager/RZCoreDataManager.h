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

@class RZDataImporter;

@interface RZCoreDataManager : RZDataManager

//! Attempt automatic lightweight migration when building data stack. Defaults to YES
@property (nonatomic, assign) BOOL attemptAutomaticMigration;

//! Delete the database file if creation of the persistent store coordinator fails. Defaults to YES.
@property (nonatomic, assign) BOOL deleteDatabaseIfUnreadable;

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

//! Clears out CoreData stack and posts reset notification. Will be rebuilt via lazy-load on next access to the MOC.
- (void)resetDatabase;

@end
