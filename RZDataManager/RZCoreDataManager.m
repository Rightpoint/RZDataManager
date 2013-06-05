//
//  RZCoreDataManager.m
//
//  Created by Joe Goullaud on 2/12/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZCoreDataManager.h"
#import "NSDictionary+NonNSNull.h"

// For storing moc reference in thread dictionary
static NSString* const kRZCoreDataManagerConfinedMocKey = @"RZCoreDataManagerConfinedMoc";

@interface RZCoreDataManager ()

@property (nonatomic, readonly) NSManagedObjectContext *currentMoc;
@property (nonatomic, strong) NSManagedObjectContext *backgroundMoc;

- (id)objectForEntity:(NSString*)entity withValue:(id)value forKeyPath:(NSString*)keyPath usingMOC:(NSManagedObjectContext*)moc create:(BOOL)create;
- (NSArray*)objectsForEntity:(NSString*)entity matchingPredicate:(NSPredicate*)predicate usingMOC:(NSManagedObjectContext*)moc;

- (void)saveContext:(BOOL)wait;
- (NSURL*)applicationDocumentsDirectory;

@end

@implementation RZCoreDataManager

#pragma mark - RZDataManager Subclass

- (id)objectOfType:(NSString *)type withValue:(id)value forKeyPath:(NSString *)keyPath createNew:(BOOL)createNew options:(NSDictionary *)options
{
    // interpret type as entity name
    return [self objectForEntity:type withValue:value forKeyPath:keyPath usingMOC:self.currentMoc create:createNew];
}

- (id)objectsOfType:(NSString *)type matchingPredicate:(NSPredicate *)predicate options:(NSDictionary *)options
{
    return [self objectsForEntity:type matchingPredicate:predicate usingMOC:self.currentMoc];
}

- (void)importData:(NSDictionary *)data objectType:(NSString *)type options:(NSDictionary *)options completion:(RZDataManagerImportCompletionBlock)completion
{
    RZDataManagerModelObjectMapping *mapping = [self mappingForObjectType:type options:options];
    
    NSString *dataIdKey = mapping.dataIdKey;
    NSString *modelIdKey = mapping.modelIdPropertyName;
    
    if (!dataIdKey || !modelIdKey){
        NSLog(@"RZCoreDataManager: [ERROR] missing data and/or model ID keys for object of type %@", type);
        return;
    }
        
    void (^InternalImportBlock)(NSDictionary *dict) = ^(NSDictionary* dict){
        
        id obj = nil;
        id uid = [dict validObjectForKey:dataIdKey decodeHTML:NO];
        
        if (uid){
            obj = [self objectOfType:type withValue:uid forKeyPath:modelIdKey createNew:YES options:nil];
            [self.dataImporter importData:dict toObject:obj usingMapping:mapping];
        }
        else{
            NSLog(@"RZCoreDataManger: Unique value for key %@ on entity named %@ is nil.", dataIdKey, type);
        }
    };
    
    [self importInBackgroundUsingBlock:^{
        
        if ([data isKindOfClass:[NSDictionary class]]){
            InternalImportBlock(data);
        }
        else if ([data isKindOfClass:[NSArray class]]){
            [(NSArray*)data enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                InternalImportBlock(obj);
            }];
        }
        else{
            NSLog(@"RZCoreDataManager: Cannot import data of type %@. Expected NSDictionary or NSArray", NSStringFromClass([data class]));
        }

                
    } completion:^(NSError *error){
        
        if (completion){
            
            // Need to fetch object from main thread moc for completion block
            id result = nil;
            if (!error){
                
                if ([data isKindOfClass:[NSDictionary class]]){
                    id uid = [data validObjectForKey:dataIdKey decodeHTML:NO];
                    result = [self objectOfType:type withValue:uid forKeyPath:dataIdKey createNew:NO options:nil];
                }
                else if ([data isKindOfClass:[NSArray class]]){
                    
                    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:[(NSArray*)data count]];
                    [(NSArray*)data enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
                    {
                        id uid = [obj validObjectForKey:dataIdKey decodeHTML:NO];
                        id resultEntry = [self objectOfType:type withValue:uid forKeyPath:dataIdKey createNew:NO options:nil];
                        if (resultEntry){
                            [resultArray addObject:resultEntry];
                        }
                    }];
                    
                    result = resultArray;
                }
                

            }
        
            completion(result, error);
        }
        
    }];
}

- (void)importData:(NSDictionary *)data objectType:(NSString *)type forRelationship:(NSString *)relationshipKey onObject:(id)otherObject options:(NSDictionary *)options completion:(RZDataManagerImportCompletionBlock)completion
{
    RZDataManagerModelObjectMapping *mapping = [self mappingForObjectType:type options:options];
    
    NSString *dataIdKey = mapping.dataIdKey;
    NSString *modelIdKey = mapping.modelIdPropertyName;
    
    if (!dataIdKey || !modelIdKey){
        NSLog(@"RZCoreDataManager: [ERROR] missing data and/or model ID keys for object of type %@", type);
        return;
    }
    
    void (^InternalImportBlock)(NSDictionary *dict) = ^(NSDictionary* dict){
        
        id obj = nil;
        id uid = [dict validObjectForKey:dataIdKey decodeHTML:NO];
        if (uid){
            
            NSEntityDescription *entityDesc = [(NSManagedObject*)otherObject entity];
            NSRelationshipDescription *relationshipDesc = [[entityDesc relationshipsByName] objectForKey:relationshipKey];
            if (relationshipDesc){
                
                // need to be able to handle many-to-many
                if (relationshipDesc.isToMany){
                    
                    // find/create related object
                    obj = [self objectOfType:type withValue:uid forKeyPath:modelIdKey createNew:YES options:nil];
                    
                    [self.dataImporter importData:dict toObject:obj];
                    
                    // create selector string for making relationship
                    NSString *selectorString = [NSString stringWithFormat:@"add%@Object:", relationshipKey.capitalizedString];
                    SEL relationshipSel = NSSelectorFromString(selectorString);
                    
                    // Ignore selector leak warning - it won't leak
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [otherObject performSelector:relationshipSel withObject:obj];
#pragma clang diagnostic pop
                    
                }
                else{
                    
                    // create or update object
                    obj = [self objectOfType:type withValue:uid forKeyPath:modelIdKey createNew:YES options:nil];
                    [self.dataImporter importData:dict toObject:obj];
                    
                    // set relationship on other object
                    [otherObject setValue:obj forKey:relationshipKey];
                }
            }
            else{
                NSLog(@"RZCoreDataManger: Could not find relationship %@ on entity named %@", relationshipKey, entityDesc.name);
            }
        }
        else{
            NSLog(@"RZCoreDataManger: Unique value for key %@ on entity named %@ is nil.", dataIdKey, type);
        }
    };
    
    [self importInBackgroundUsingBlock:^{
        
        if ([data isKindOfClass:[NSDictionary class]]){
            InternalImportBlock(data);
        }
        else if ([data isKindOfClass:[NSArray class]]){
            [(NSArray*)data enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                InternalImportBlock(obj);
            }];
        }
        else{
            NSLog(@"RZCoreDataManager: Cannot import data of type %@. Expected NSDictionary or NSArray", NSStringFromClass([data class]));
        }
        
    } completion:^(NSError *error) {
        
        if (completion){
            
            // Need to fetch object from main thread moc for completion block
            id result = nil;
            if (!error){
                
                if ([data isKindOfClass:[NSDictionary class]]){
                    id uid = [data validObjectForKey:dataIdKey decodeHTML:NO];
                    result = [self objectOfType:type withValue:uid forKeyPath:dataIdKey createNew:NO options:nil];
                }
                else if ([data isKindOfClass:[NSArray class]]){
                    
                    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:[(NSArray*)data count]];
                    [(NSArray*)data enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
                     {
                         id uid = [obj validObjectForKey:dataIdKey decodeHTML:NO];
                         id resultEntry = [self objectOfType:type withValue:uid forKeyPath:dataIdKey createNew:NO options:nil];
                         if (resultEntry){
                             [resultArray addObject:resultEntry];
                         }
                     }];
                    
                    result = resultArray;
                }
                
                
            }
            
            completion(result, error);
        }

        
    }];
}


- (void)importInBackgroundUsingBlock:(RZDataManagerImportBlock)importBlock completion:(void(^)(NSError *error))completionBlock;
{
    // only setup new moc if on main thread, otherwise assume we are on a background thread with associated moc
    
    void (^internalImportBlock)(NSManagedObjectContext *privateMoc) = ^(NSManagedObjectContext *privateMoc){
        
        importBlock();
        
        NSError *error = nil;
        if(![privateMoc save:&error])
        {
            NSLog(@"Error saving import in background. Error: %@", error);
        }
        
        dispatch_sync(dispatch_get_main_queue(), ^{
                        
            if (completionBlock)
            {
                completionBlock(error);
            }
        });
    };
    
    if ([NSThread isMainThread]){
        
        NSManagedObjectContext *privateMoc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        privateMoc.parentContext = self.managedObjectContext;
        
        [privateMoc performBlock:^{
            
            if (![NSThread isMainThread]){
                [[[NSThread currentThread] threadDictionary] setObject:privateMoc forKey:kRZCoreDataManagerConfinedMocKey];
            }
            
            internalImportBlock(privateMoc);
        }];
    }
    else{
        NSManagedObjectContext *moc = self.currentMoc;
        if (moc){
            internalImportBlock(moc);
        }
        else{
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"RZDataManager attempting to import on a thread with no MOC" userInfo:nil];
        }
    }
}


- (void)saveData:(BOOL)synchronous
{
    [self saveContext:synchronous];
}

- (void)discardChanges
{
    [self.managedObjectContext rollback];
}

#pragma mark - Properties

- (NSManagedObjectContext*)currentMoc
{
    NSManagedObjectContext *moc = nil;
    
    // If on main thread, use main moc. If not, use moc from thread dictionary.
    if ([NSThread isMainThread]){
        moc = self.managedObjectContext;
    }
    else{
        moc = [[[NSThread currentThread] threadDictionary] objectForKey:kRZCoreDataManagerConfinedMocKey];
    }
    
    return moc;
}

#pragma mark - Retrieval Methods

- (id)objectForEntity:(NSString*)entity withValue:(id)value forKeyPath:(NSString*)keyPath usingMOC:(NSManagedObjectContext*)moc create:(BOOL)create
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entity];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", keyPath, value];
    
    NSError* error = nil;
    NSArray* arr = [moc executeFetchRequest:request error:&error];
    
    id fetchedObject = [arr lastObject];
    
    if (nil == fetchedObject && create)
    {
        fetchedObject = [NSEntityDescription insertNewObjectForEntityForName:entity inManagedObjectContext:moc];
        [fetchedObject setValue:value forKeyPath:keyPath];
    }
    
    return fetchedObject;
}


- (NSArray*)objectsForEntity:(NSString*)entity matchingPredicate:(NSPredicate*)predicate usingMOC:(NSManagedObjectContext*)moc
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entity];
    request.predicate = predicate;
    
    NSError* error = nil;
    NSArray* arr = [moc executeFetchRequest:request error:&error];
    
    return arr;
}

#pragma mark - Core Data Stack

// Returns the background managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext*)backgroundMoc
{
    if (nil == _backgroundMoc)
    {
        NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
        if (coordinator != nil) {
            _backgroundMoc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            _backgroundMoc.persistentStoreCoordinator = coordinator;
        }
    }
    
    return _backgroundMoc;
}

// Returns the main managed object context for the application.
// If the context doesn't already exist, it is created and bound to the backgroundMoc for the application.
- (NSManagedObjectContext*)managedObjectContext
{
    if (nil == _managedObjectContext)
    {
        NSManagedObjectContext *backgroundMoc = self.backgroundMoc;
        if (backgroundMoc != nil) {
            _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            _managedObjectContext.parentContext = backgroundMoc;
            _managedObjectContext.undoManager = [[NSUndoManager alloc] init];
        }
    }
    
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel*)managedObjectModel
{
    if (nil == _managedObjectModel)
    {
        NSURL *modelURL = [[NSBundle mainBundle] URLForResource:self.managedObjectModelName withExtension:@"momd"];
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    }
    
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator*)persistentStoreCoordinator
{
    if (nil == _persistentStoreCoordinator)
    {
        NSError *error = nil;
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
        if(![_persistentStoreCoordinator addPersistentStoreWithType:self.persistentStoreType configuration:nil URL:self.persistentStoreURL options:nil error:&error])
        {
            if (NSSQLiteStoreType == self.persistentStoreType && self.persistentStoreURL)
            {
                NSError *removeFileError = nil;
                if([[NSFileManager defaultManager] removeItemAtURL:self.persistentStoreURL error:&removeFileError])
                {
                    if([_persistentStoreCoordinator addPersistentStoreWithType:self.persistentStoreType configuration:nil URL:self.persistentStoreURL options:nil error:&error])
                    {
                        // Succeeded! - Nil out previous error to avoid abort
                        error = nil;
                    }
                }
                else
                {
                    error = removeFileError;
                }
            }
            
            if (nil != error)
            {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
        }
    }
    
    return _persistentStoreCoordinator;
}

- (NSString*)managedObjectModelName
{
    if (nil == _managedObjectModelName)
    {
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        NSMutableString *productName = [[info objectForKey:@"CFBundleDisplayName"] mutableCopy];
        [productName replaceOccurrencesOfString:@" " withString:@"_" options:0 range:NSMakeRange(0, productName.length)];
        [productName replaceOccurrencesOfString:@"-" withString:@"_" options:0 range:NSMakeRange(0, productName.length)];
        _managedObjectModelName = [NSString stringWithString:productName];
    }
    
    return _managedObjectModelName;
}

- (NSString*)persistentStoreType
{
    if (nil == _persistentStoreType)
    {
        _persistentStoreType = NSInMemoryStoreType;
    }
    
    return _persistentStoreType;
}

- (NSURL*)persistentStoreURL
{
    if (nil == _persistentStoreURL)
    {
        if (NSSQLiteStoreType == self.persistentStoreType)
        {
            NSString *storeFileName = [self.managedObjectModelName stringByAppendingPathExtension:@"sqlite"];
            _persistentStoreURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:storeFileName];
        }
    }
    
    return _persistentStoreURL;
}

// Adapted from Core Data (Second Edition) By Marcus Zarra http://pragprog.com/book/mzcd2/core-data
- (void)saveContext:(BOOL)wait
{
    NSManagedObjectContext *moc = self.managedObjectContext;
    NSManagedObjectContext *backgroundMoc = self.backgroundMoc;
    
    if (nil == moc)
    {
        return;
    }
    
    if ([moc hasChanges])
    {
        [moc performBlockAndWait:^{
            NSError *error = nil;
            if(![moc save:&error])
            {
                NSLog(@"Error saving changes for main MOC. Error: %@", error);
            }
        }];
    }
    
    void (^saveBackground)(void) = ^{
        NSError *error = nil;
        if(![backgroundMoc save:&error])
        {
            NSLog(@"Error saving changes to disk. Error: %@", error);
        }
    };
    
    if ([backgroundMoc hasChanges])
    {
        if (wait)
        {
            [backgroundMoc performBlockAndWait:saveBackground];
        }
        else
        {
            [backgroundMoc performBlock:saveBackground];
        }
    }
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL*)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
