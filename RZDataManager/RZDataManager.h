//
//  RZDataManager.h
//
//  Created by Joe Goullaud on 2/12/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

typedef void (^RZDataManagerCompletionBlock)();
typedef void (^RZDataManagerImportBlock)(NSManagedObjectContext* moc);

@interface RZDataManager : NSObject

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, strong) NSString *managedObjectModelName;
@property (nonatomic, strong) NSString *persistentStoreType;
@property (nonatomic, strong) NSURL *persistentStoreURL;

+ (RZDataManager*)defaultManager;

- (void)importInBackgroundUsingBlock:(RZDataManagerImportBlock)importBlock completion:(RZDataManagerCompletionBlock)completionBlock;

- (id)objectForEntity:(NSString*)entity withValue:(id)value forKeyPath:(NSString*)keyPath usingMOC:(NSManagedObjectContext*)moc;

- (id)objectForEntity:(NSString*)entity withValue:(id)value forKeyPath:(NSString*)keyPath usingMOC:(NSManagedObjectContext*)moc create:(BOOL)create;

- (id)objectForEntity:(NSString*)entity withValue:(id)value forKeyPath:(NSString*)keyPath where:(NSPredicate*)predicate usingMOC:(NSManagedObjectContext*)moc create:(BOOL)create;

- (id)objectForEntity:(NSString*)entity withValue:(id)value forKeyPath:(NSString*)keyPath inSet:(NSSet*)objects usingMOC:(NSManagedObjectContext*)moc create:(BOOL)create;

- (NSArray*)objectsForEntity:(NSString*)entity usingMOC:(NSManagedObjectContext*)moc;
- (NSArray*)objectsForEntity:(NSString*)entity sortDescriptors:(NSArray*)sortDescriptors usingMOC:(NSManagedObjectContext*)moc;


- (void)saveContext:(BOOL)wait;
- (NSURL*)applicationDocumentsDirectory;

@end
