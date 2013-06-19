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
 * 2) Performing an import DOES NOT SAVE to disk. This allows "undo" of all changes
 *    to objects on the public MOC since the last save.
 *
 * 3) On that note, calling save on the public MOC will NOT persist to disk! Use
 *    saveContext: instead.
 *
 * 4) importInBackgroundUsingBlock: can be used to perform any managed object graph
 *    or object modifications in the background, not just imports.
 *
 ************************************************************************************/


@class RZDataImporter;

@interface RZCoreDataManager : RZDataManager

@property (nonatomic, strong) NSString *managedObjectModelName;
@property (nonatomic, strong) NSString *persistentStoreType;
@property (nonatomic, strong) NSURL *persistentStoreURL;

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end
