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

@property (nonatomic, strong) NSString *managedObjectModelName;
@property (nonatomic, strong) NSString *persistentStoreType;
@property (nonatomic, strong) NSURL *persistentStoreURL;

+ (RZCoreDataManager*)defaultManager;

@end
