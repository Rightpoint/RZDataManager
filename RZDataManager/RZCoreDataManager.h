//
//  RZCoreDataManager.h
//
//  Created by Joe Goullaud on 2/12/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "RZDataManager.h"

@class RZDataImporter;

@interface RZCoreDataManager : RZDataManager

+ (RZCoreDataManager*)defaultManager;

@property (nonatomic, strong) NSString *managedObjectModelName;
@property (nonatomic, strong) NSString *persistentStoreType;
@property (nonatomic, strong) NSURL *persistentStoreURL;

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end
