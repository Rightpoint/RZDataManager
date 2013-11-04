//
//  RZCoreDataManager.m
//
//  Created by Joe Goullaud on 2/12/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZCoreDataManager.h"
#import "NSDictionary+NonNSNull.h"
#import "NSObject+RZPropertyUtils.h"

// Number of items to import in a single batch when importing a lot of items
#define kRZCoreDataManagerImportBatchBlockSize 50

// For storing moc reference in thread dictionary
static NSString *const kRZCoreDataManagerConfinedMocKey = @"RZCoreDataManagerConfinedMoc";

NSString *const RZCoreDataManagerImportAsynchronouslyOptionKey = @"RZCoreDataManagerImportAsynhcronously";

static dispatch_queue_t s_RZCoreDataManagerPrivateImportQueue = nil;
static char *const s_RZCoreDataManagerPrivateImportQueueName = "com.raizlabs.RZCoreDataManagerImport";

NSString *const RZCoreDataManagerWillDeleteInvalidDatabaseFile  = @"RZCoreDataManagerWillDeleteInvalidDatabaseFile";
NSString *const RZCoreDataManagerDidDeleteInvalidDatabaseFile   = @"RZCoreDataManagerDidDeleteInvalidDatabaseFile";
NSString *const RZCoreDataManagerWillResetDatabaseNotification  = @"RZCoreDataManagerWillResetDatabase";
NSString *const RZCoreDataManagerDidResetDatabaseNotification   = @"RZCoreDataManagerDidResetDatabase";

@interface RZCoreDataManager ()

@property (nonatomic, readonly) NSManagedObjectContext *currentMoc;
@property (nonatomic, strong) NSManagedObjectContext   *backgroundMoc;
@property (nonatomic, strong) NSMutableDictionary      *classToEntityMapping;

- (id)objectForEntity:(NSString *)entity
            withValue:(id)value
           forKeyPath:(NSString *)keyPath
             usingMOC:(NSManagedObjectContext *)moc
               create:(BOOL)create;

- (id)objectForEntity:(NSString *)entity
            withValue:(id)value
           forKeyPath:(NSString *)keyPath
         inCollection:(id)objects
             usingMOC:(NSManagedObjectContext *)moc
               create:(BOOL)create;


- (NSArray *)objectsForEntity:(NSString *)entity
            matchingPredicate:(NSPredicate *)predicate
                     usingMOC:(NSManagedObjectContext *)moc;

- (void)handleDataImportWithEntityName:(NSString *)entityName
                               mapping:(RZDataManagerModelObjectMapping *)mapping
                               options:(NSDictionary *)options
                               andData:(id)dictionaryOrArray
                        importedObjIds:(NSMutableArray *const __autoreleasing*)importedObjIds;

- (void)performRelationshipImportsOnObject:(NSObject *)obj
                               withMapping:(RZDataManagerModelObjectMapping *)mapping
                                  fromData:(id)dictionaryOrArray;

- (void)handleRelationshipImportOnObject:(NSObject *)object
                 withRelationshipMapping:(RZDataManagerModelObjectRelationshipMapping *)relationshipMapping
                           objectMapping:(RZDataManagerModelObjectMapping *)objectMapping
                                 andData:(id)dictionaryOrArray;

- (void)saveContext:(BOOL)wait;

- (NSURL *)applicationDocumentsDirectory;

- (NSString *)classNameForEntityOrClassNamed:(NSString *)name;
- (NSString *)entityNameForClassOrEntityNamed:(NSString *)name;

@end

@implementation RZCoreDataManager

- (id)init
{
    self = [super init];
    if (self)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            s_RZCoreDataManagerPrivateImportQueue = dispatch_queue_create(s_RZCoreDataManagerPrivateImportQueueName, NULL);
        });
        
        _classToEntityMapping       = [NSMutableDictionary dictionary];
        _attemptAutomaticMigration  = YES;
        _deleteDatabaseIfUnreadable = YES;
    }
    return self;
}

#pragma mark - RZDataManager Subclass

- (id)objectOfType:(NSString *)type withValue:(id)value forKeyPath:(NSString *)keyPath createNew:(BOOL)createNew
{
    return [self objectForEntity:type withValue:value forKeyPath:keyPath usingMOC:self.currentMoc create:createNew];
}

- (id)objectOfType:(NSString *)className
         withValue:(id)value
        forKeyPath:(NSString *)keyPath
      inCollection:(id)collection
         createNew:(BOOL)createNew
{
    return [self objectForEntity:className withValue:value forKeyPath:keyPath inCollection:collection usingMOC:self.currentMoc create:createNew];
}

- (id)objectsOfType:(NSString *)className matchingPredicate:(NSPredicate *)predicate
{
    return [self objectsForEntity:className matchingPredicate:predicate usingMOC:self.currentMoc];
}

- (void)importData:(NSDictionary *)data
     forClassNamed:(NSString *)className
      usingMapping:(RZDataManagerModelObjectMapping *)mapping
           options:(NSDictionary *)options
        completion:(RZDataManagerImportCompletionBlock)completion
{
    // make sure it's a class name, not an entity name
    className = [self classNameForEntityOrClassNamed:className];
    
    if (nil == mapping)
    {
        mapping = [self.dataImporter mappingForClassNamed:className];
    }

    NSString *dataIdKey  = mapping.dataIdKey;
    NSString *modelIdKey = mapping.modelIdPropertyName;

    if (!dataIdKey || !modelIdKey)
    {
        RZDataManagerLogError(@"Missing data and/or model ID keys for object of type %@", className);
        return;
    }

    __block NSMutableArray *importedObjectIDs = [NSMutableArray array];

    BOOL synchronousImport = ![[options objectForKey:RZCoreDataManagerImportAsynchronouslyOptionKey] boolValue];

    [self importInBackgroundSynchronously:synchronousImport usingBlock:^(NSManagedObjectContext *moc)
    {
        [self handleDataImportWithEntityName:[self entityNameForClassOrEntityNamed:className]
                                     mapping:mapping
                                     options:options
                                     andData:data
                              importedObjIds:&importedObjectIDs];
    }
    completion:^(NSError *error)
    {

        if ([[options objectForKey:RZDataManagerSaveAfterImportOptionKey] boolValue])
        {
            [self saveContext:YES];
        }

        if (completion)
        {

            // Need to fetch object from main thread moc for completion block
            id result = nil;
            if (error == nil && [[options objectForKey:RZDataManagerReturnObjectsFromImportOptionKey] boolValue])
            {

                if ([data isKindOfClass:[NSDictionary class]])
                {
                    id uid = [data validObjectForKey:dataIdKey decodeHTML:NO];
                    result = [self objectOfType:className withValue:uid forKeyPath:modelIdKey createNew:NO];
                }
                else if ([data isKindOfClass:[NSArray class]])
                {
                    NSMutableArray *resultArray = [NSMutableArray array];
                    [importedObjectIDs enumerateObjectsUsingBlock:^(NSManagedObjectID *objID, NSUInteger idx, BOOL *stop)
                    {
                        [resultArray addObject:[self.managedObjectContext objectWithID:objID]];
                    }];

                    result = resultArray;
                }


            }

            completion(result, error);
        }

    }];
}

- (void)        importData:(id)data
forRelationshipWithMapping:(RZDataManagerModelObjectRelationshipMapping *)relationshipMapping
                  onObject:(NSObject *)object
                   options:(NSDictionary *)options
                completion:(RZDataManagerImportCompletionBlock)completion
{
    NSString *objectClassName = NSStringFromClass([object class]);

    // use mapping attached to relationship mapping, otherwise get it from the importer
    RZDataManagerModelObjectMapping *objMapping = [relationshipMapping relatedObjectMapping];
    if (nil == objMapping)
    {
        objMapping = [self.dataImporter mappingForClassNamed:[self classNameForEntityOrClassNamed:relationshipMapping.relationshipClassName]];
    }

    NSString *dataIdKey  = objMapping.dataIdKey;
    NSString *modelIdKey = objMapping.modelIdPropertyName;

    if (!dataIdKey || !modelIdKey)
    {
        RZDataManagerLogError(@"Missing data and/or model ID keys for object of type %@", objectClassName);
        return;
    }

    BOOL synchronousImport = ![[options objectForKey:RZCoreDataManagerImportAsynchronouslyOptionKey] boolValue];

    [self importInBackgroundSynchronously:synchronousImport usingBlock:^(NSManagedObjectContext *moc)
    {
        [self handleRelationshipImportOnObject:object
                       withRelationshipMapping:relationshipMapping
                                 objectMapping:objMapping
                                       andData:data];
    }
    completion:^(NSError *error)
    {

        if ([[options objectForKey:RZDataManagerSaveAfterImportOptionKey] boolValue])
        {
            [self saveContext:YES];
        }

        if (completion)
        {

            // Need to fetch object from main thread moc for completion block
            id result = nil;
            if (error == nil && [[options objectForKey:RZDataManagerReturnObjectsFromImportOptionKey] boolValue])
            {
                if ([data isKindOfClass:[NSDictionary class]])
                {
                    id uid = [data validObjectForKey:dataIdKey decodeHTML:NO];
                    result = [self objectOfType:relationshipMapping.relationshipClassName withValue:uid forKeyPath:modelIdKey createNew:NO];
                }
                else if ([data isKindOfClass:[NSArray class]])
                {
                    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:[(NSArray *)data count]];
                    [(NSArray *)data enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
                    {
                        id uid         = [obj validObjectForKey:dataIdKey decodeHTML:NO];
                        id resultEntry = [self objectOfType:relationshipMapping.relationshipClassName withValue:uid forKeyPath:modelIdKey createNew:NO];
                        if (resultEntry)
                        {
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

- (void)performDataOperationInBackgroundUsingBlock:(RZDataManagerOperationBlock)importBlock
                                        completion:(RZDataManagerBackgroundOperationCompletionBlock)completionBlock
{
    [self importInBackgroundSynchronously:YES usingBlock:importBlock completion:completionBlock];
}

- (void)importInBackgroundSynchronously:(BOOL)synchronously
                             usingBlock:(RZDataManagerOperationBlock)importBlock
                             completion:(RZDataManagerBackgroundOperationCompletionBlock)completionBlock;
{
    // only setup new moc if on main thread, otherwise assume we are on a background thread with associated moc


    void (^internalImportBlock)(BOOL, NSManagedObjectContext *) = ^(BOOL fromMainThread, NSManagedObjectContext *privateMoc)
    {

        importBlock(privateMoc);

        NSError *error = nil;
        if (![privateMoc save:&error])
        {
            RZDataManagerLogError(@"Error saving import in background: %@", error);
        }

        [self.managedObjectContext performBlockAndWait:^
        {
            [self.managedObjectContext processPendingChanges];
        }];

        if (fromMainThread)
        {
            dispatch_sync(dispatch_get_main_queue(), ^
            {
                if (completionBlock)
                {
                    completionBlock(error);
                }
            });
        }
        else
        {
            if (completionBlock)
            {
                completionBlock(error);
            }
        }
    };

    if ([NSThread isMainThread])
    {

        if (synchronously)
        {
            dispatch_async(s_RZCoreDataManagerPrivateImportQueue, ^
            {

                NSManagedObjectContext *privateMoc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
                privateMoc.parentContext = self.managedObjectContext;
                privateMoc.undoManager   = nil; // should be nil already, but let's make it explicit

                if (![NSThread isMainThread])
                {
                    [[[NSThread currentThread] threadDictionary] setObject:privateMoc forKey:kRZCoreDataManagerConfinedMocKey];
                }

                internalImportBlock(YES, privateMoc);
            });
        }
        else
        {
            NSManagedObjectContext *privateMoc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            privateMoc.parentContext = self.managedObjectContext;
            privateMoc.undoManager   = nil; // should be nil already, but let's make it explicit

            [privateMoc performBlock:^
            {

                if (![NSThread isMainThread])
                {
                    [[[NSThread currentThread] threadDictionary] setObject:privateMoc forKey:kRZCoreDataManagerConfinedMocKey];
                }

                internalImportBlock(YES, privateMoc);
            }];
        }

    }
    else
    {
        NSManagedObjectContext *moc = self.currentMoc;
        if (moc)
        {

            if (moc.concurrencyType == NSPrivateQueueConcurrencyType)
            {
                // we can perform this and wait safely on a bg thread
                [moc performBlockAndWait:^
                {
                    internalImportBlock(NO, moc);
                }];
            }
            else
            {
                internalImportBlock(NO, moc);
            }
        }
        else
        {
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

- (NSManagedObjectContext *)currentMoc
{
    NSManagedObjectContext *moc = nil;

    // If on main thread, use main moc. If not, use moc from thread dictionary.
    if ([NSThread isMainThread])
    {
        moc = self.managedObjectContext;
    }
    else
    {
        moc = [[[NSThread currentThread] threadDictionary] objectForKey:kRZCoreDataManagerConfinedMocKey];
    }

    return moc;
}

#pragma mark - Utilities

- (NSString *)entityNameForClassOrEntityNamed:(NSString *)name
{
    __block NSString *entityName = [self.classToEntityMapping objectForKey:name];
    if (nil == entityName)
    {
        NSDictionary *entities = [self.managedObjectModel entitiesByName];

        if ([[entities allKeys] containsObject:name])
        {
            // if it's an entity name, don't update the cache
            entityName = name;
        }
        else
        {
            // if it's a class name, update the cache
            [entities enumerateKeysAndObjectsUsingBlock:^(NSString *eName, NSEntityDescription *eDesc, BOOL *stop)
            {

                if ([eDesc.managedObjectClassName isEqualToString:name])
                {
                    entityName = eName;
                    *stop = YES;
                }

            }];

            if (nil != entityName)
            {
                [self.classToEntityMapping setObject:entityName forKey:name];
            }

        }
    }

    if (nil == entityName)
    {
        @throw [NSException exceptionWithName:kRZDataManagerException
                                       reason:[NSString stringWithFormat:@"CoreData model does not contain entity or managed object class named %@", name]
                                     userInfo:nil];
    }

    return entityName;
}

- (NSString *)classNameForEntityOrClassNamed:(NSString *)name
{
    __block NSString *className = [[self.classToEntityMapping allKeysForObject:name] lastObject];
    if (nil == className)
    {
        NSDictionary *entities = [self.managedObjectModel entitiesByName];
        
        if ([[entities allKeys] containsObject:name])
        {
            // if it's an entity name, update the cache
            className = [[entities objectForKey:name] managedObjectClassName];
            [self.classToEntityMapping setObject:name forKey:className];
        }
        else
        {
            // if it's a class name, don't update the cache
            [entities enumerateKeysAndObjectsUsingBlock:^(NSString *eName, NSEntityDescription *eDesc, BOOL *stop)
             {
                 
                 if ([eDesc.managedObjectClassName isEqualToString:name])
                 {
                     className = name;
                     *stop = YES;
                 }
                 
             }];
        }
    }
    
    if (nil == className)
    {
        @throw [NSException exceptionWithName:kRZDataManagerException
                                       reason:[NSString stringWithFormat:@"CoreData model does not contain entity or managed object class named %@", name]
                                     userInfo:nil];
    }
    return className;
}

#pragma mark - Retrieval Methods

- (id)objectForEntity:(NSString *)entity
            withValue:(id)value
           forKeyPath:(NSString *)keyPath
             usingMOC:(NSManagedObjectContext *)moc
               create:(BOOL)create
{
    // ensure this is an entity type, not the class name
    entity = [self entityNameForClassOrEntityNamed:entity];

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entity];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", keyPath, value];

    NSError *error = nil;
    
    [self.managedObjectContext lock];
    NSArray *arr   = [moc executeFetchRequest:request error:&error];
    [self.managedObjectContext unlock];

    id fetchedObject = [arr lastObject];

    if (nil == fetchedObject && create)
    {
        fetchedObject = [NSEntityDescription insertNewObjectForEntityForName:entity inManagedObjectContext:moc];
        [fetchedObject setValue:value forKeyPath:keyPath];
    }

    return fetchedObject;
}

- (id)objectForEntity:(NSString *)entity
            withValue:(id)value
           forKeyPath:(NSString *)keyPath
         inCollection:(id)objects
             usingMOC:(NSManagedObjectContext *)moc
               create:(BOOL)create
{
    // ensure this is an entity type, not the class name
    entity = [self entityNameForClassOrEntityNamed:entity];

    id fetchedObject = nil;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", keyPath, value];

    if ([objects isKindOfClass:[NSSet class]])
    {
        NSSet *filteredObjects = [objects filteredSetUsingPredicate:predicate];
        fetchedObject = [filteredObjects anyObject];
    }
    else if ([objects isKindOfClass:[NSArray class]])
    {
        NSArray *filteredObjects = [objects filteredArrayUsingPredicate:predicate];
        if (filteredObjects.count > 0)
        {
            fetchedObject = [filteredObjects objectAtIndex:0];
        }
    }

    if (nil == fetchedObject && create)
    {
        fetchedObject = [NSEntityDescription insertNewObjectForEntityForName:entity inManagedObjectContext:moc];
        [fetchedObject setValue:value forKeyPath:keyPath];
    }

    return fetchedObject;
}


- (NSArray *)objectsForEntity:(NSString *)entity
            matchingPredicate:(NSPredicate *)predicate
                     usingMOC:(NSManagedObjectContext *)moc
{
    // ensure this is an entity type, not the class name
    entity = [self entityNameForClassOrEntityNamed:entity];

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entity];
    request.predicate = predicate;

    NSError *error = nil;
    
    [self.managedObjectContext lock];
    NSArray *arr   = [moc executeFetchRequest:request error:&error];
    [self.managedObjectContext unlock];

    return arr;
}

#pragma mark - Private import methods

- (void)handleDataImportWithEntityName:(NSString *)entityName
                               mapping:(RZDataManagerModelObjectMapping *)mapping
                               options:(NSDictionary *)options
                               andData:(id)dictionaryOrArray
                        importedObjIds:(NSMutableArray * const __autoreleasing *)importedObjIds
{
    NSString *dataIdKey  = mapping.dataIdKey;
    NSString *modelIdKey = mapping.modelIdPropertyName;

    if ([dictionaryOrArray isKindOfClass:[NSDictionary class]])
    {
        id obj = nil;
        id uid = [dictionaryOrArray validObjectForKey:dataIdKey decodeHTML:NO];
        
        if (uid)
        {
            obj = [self objectOfType:entityName withValue:uid forKeyPath:modelIdKey createNew:YES];
            if ([obj respondsToSelector:@selector(dataImportPerformImportWithData:)])
            {
                [obj dataImportPerformImportWithData:dictionaryOrArray];
            }
            else
            {
                [self.dataImporter importData:dictionaryOrArray toObject:obj usingMapping:mapping];
            }
            
            // check for relationships
            [self performRelationshipImportsOnObject:obj withMapping:mapping fromData:dictionaryOrArray];
            
            
            // delete other items if necessary
            if ([[options valueForKey:RZDataManagerReplaceItemsOptionKey] boolValue])
            {
                // fetch items that aren't this item
                NSFetchRequest *otherItemsFetch = [NSFetchRequest fetchRequestWithEntityName:entityName];
                otherItemsFetch.predicate = [NSPredicate predicateWithFormat:@"SELF != %@", obj];
                otherItemsFetch.includesPropertyValues = NO;
                
                NSArray *otherItems = [self.currentMoc executeFetchRequest:otherItemsFetch error:NULL];
                
                for (NSManagedObject *item in otherItems)
                {
                    [self.currentMoc deleteObject:item];
                }
            }
        }
        else
        {
            RZDataManagerLogError(@"Unique value for key %@ on entity named %@ is nil.", dataIdKey, entityName);
        }
    }
    else if ([dictionaryOrArray isKindOfClass:[NSArray class]])
    {
        
        // optimize lookup for existing objects
        NSEntityDescription *entityDesc  = [NSEntityDescription entityForName:entityName inManagedObjectContext:self.managedObjectContext];
        NSDictionary        *entityProps = [entityDesc propertiesByName];
        
        NSPropertyDescription *modelIdProp = [entityProps objectForKey:modelIdKey];
        
        if (modelIdProp != nil)
        {
            
            // Fetch only uid and object ID
            // Expression description solution from http://stackoverflow.com/a/4792331/1128820
            
            NSExpressionDescription *objectIdDesc = [[NSExpressionDescription alloc] init];
            objectIdDesc.name                 = @"objectID";
            objectIdDesc.expression           = [NSExpression expressionForEvaluatedObject];
            objectIdDesc.expressionResultType = NSObjectIDAttributeType;
            
            NSFetchRequest *uidFetch = [NSFetchRequest fetchRequestWithEntityName:entityName];
            [uidFetch setResultType:NSDictionaryResultType];
            [uidFetch setIncludesPendingChanges:YES];
            [uidFetch setPropertiesToFetch:@[modelIdProp, objectIdDesc]];
            
            NSError *err          = nil;
            
            [self.managedObjectContext lock];
            NSArray *existingObjs = [self.currentMoc executeFetchRequest:uidFetch error:&err];
            [self.managedObjectContext unlock];
            
            if (err == nil)
            {
                
                NSDictionary *existingObjIdsByUid = [NSDictionary dictionaryWithObjects:[existingObjs valueForKey:@"objectID"] forKeys:[existingObjs valueForKey:modelIdKey]];
                
                NSInteger  objectsRemaining = [dictionaryOrArray count];
                NSUInteger objectOffset     = 0;
                
                while (objectsRemaining > 0)
                {
                    
                    NSUInteger blockSize = MIN(objectsRemaining, kRZCoreDataManagerImportBatchBlockSize);
                    NSIndexSet *objectsToEnumerate = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(objectOffset, blockSize)];
                    
                    objectsRemaining -= blockSize;
                    objectOffset += blockSize;
                    
                    // Avoid bloating memory - only import a few objects at a time
                    @autoreleasepool
                    {
                        [(NSArray *)dictionaryOrArray enumerateObjectsAtIndexes:objectsToEnumerate options:0 usingBlock:^(id objData, NSUInteger idx, BOOL *stop)
                         {
                             id uid = [objData valueForKey:dataIdKey];
                             if (uid != nil)
                             {
                                 id importedObj = nil;
                                 NSManagedObjectID *importedObjId = [existingObjIdsByUid objectForKey:uid];
                                 
                                 if (importedObjId != nil)
                                 {
                                     NSError *existingObjErr = nil;
                                     importedObj = [self.currentMoc existingObjectWithID:importedObjId error:&existingObjErr];
                                     if (existingObjErr != nil)
                                     {
                                         RZDataManagerLogError(@"Error fetching existing object. %@", existingObjErr);
                                     }
                                     else if (importedObj == nil)
                                     {
                                         RZDataManagerLogError(@"Error: Existing object expected but not found for %@ : %@", dataIdKey, uid);
                                     }
                                 }
                                 
                                 if (importedObj == nil)
                                 {
                                     importedObj = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:self.currentMoc];
                                     
                                     // If we are creating a new object, obtain a permanent ID for it
                                     NSError *permIdErr = nil;
                                     if (![self.currentMoc obtainPermanentIDsForObjects:@[importedObj] error:&permIdErr])
                                     {
                                         RZDataManagerLogError(@"Error obtaining permanent id for new object. %@", permIdErr);
                                     }
                                 }
                                 
                                 if ([importedObj respondsToSelector:@selector(dataImportPerformImportWithData:)])
                                 {
                                     [importedObj dataImportPerformImportWithData:objData];
                                 }
                                 else
                                 {
                                     [self.dataImporter importData:objData toObject:importedObj];
                                 }
                                 
                                 // Check for relationships
                                 [self performRelationshipImportsOnObject:importedObj withMapping:mapping fromData:objData];

                                 if (importedObjIds)
                                 {
                                    [*importedObjIds addObject:[importedObj objectID]];
                                 }
                             }
                         }];
                    }
                    
                }
                
                // delete other items if necessary
                if ([[options valueForKey:RZDataManagerReplaceItemsOptionKey] boolValue])
                {
                    // fetch items that aren't this item
                    NSFetchRequest *otherItemsFetch = [NSFetchRequest fetchRequestWithEntityName:entityName];
                    otherItemsFetch.predicate = [NSPredicate predicateWithFormat:@"!(%K IN %@)", modelIdKey, [dictionaryOrArray valueForKey:dataIdKey]];
                    otherItemsFetch.includesPropertyValues = NO;
                    
                    NSArray *otherItems = [self.currentMoc executeFetchRequest:otherItemsFetch error:NULL];
                    
                    for (NSManagedObject *item in otherItems)
                    {
                        [self.currentMoc deleteObject:item];
                    }
                }
                
                // Delete stale items
                NSPredicate *stalePred = options[RZDataManagerDeleteStaleItemsPredicateOptionKey];
                
                if (stalePred != nil)
                {
                    
                    // Fetch objects to check for staleness
                    NSFetchRequest *staleFetch = [NSFetchRequest fetchRequestWithEntityName:entityName];
                    staleFetch.predicate = stalePred;
                    
                    NSError *stFetchErr     = nil;
                    [self.managedObjectContext lock];
                    NSArray *objectsToCheck = [self.currentMoc executeFetchRequest:staleFetch error:&stFetchErr];
                    [self.managedObjectContext unlock];
                    if (stFetchErr != nil)
                    {
                        RZDataManagerLogError(@"Error executing fetch for stale objects. %@", stFetchErr);
                    }
                    
                    NSSet *dataObjsUuids = [NSSet setWithArray:[(NSArray *)dictionaryOrArray valueForKey:dataIdKey]];
                    
                    [objectsToCheck enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
                     {
                         // if this model object is not present in the list of objects to import, delete it.
                         if (![dataObjsUuids containsObject:[obj valueForKey:modelIdKey]])
                         {
                             [self.currentMoc deleteObject:obj];
                         }
                     }];
                }
            }
            else
            {
                RZDataManagerLogError(@"Error fetching existing objects of type %@: %@", entityName, err);
            }
        }
        else
        {
            RZDataManagerLogError(@"No property named %@ found on entity named %@", modelIdKey, entityName);
        }
        
    }
    else
    {
        RZDataManagerLogError(@"Cannot import data of type %@. Expected NSDictionary or NSArray", NSStringFromClass([dictionaryOrArray class]));
    }

}

- (void)performRelationshipImportsOnObject:(NSObject *)obj withMapping:(RZDataManagerModelObjectMapping *)mapping fromData:(id)dictionaryOrArray
{
    // Check for relationships
    NSDictionary *relationshipMappings = mapping.allRelationshipMappings;
    NSSet *relationshipKeys = [NSSet setWithArray:relationshipMappings.allKeys];
    
    if (relationshipKeys.count)
    {
        NSMutableSet *commonKeys = [NSMutableSet setWithArray:[dictionaryOrArray allKeys]];
        [commonKeys intersectSet:relationshipKeys];
        
        [commonKeys enumerateObjectsUsingBlock:^(NSString *key, BOOL *stop) {
            
            RZDataManagerModelObjectRelationshipMapping *relMapping = [relationshipMappings objectForKey:key];
            
            // use mapping attached to relationship mapping, otherwise get it from the importer
            RZDataManagerModelObjectMapping *objMapping = [relMapping relatedObjectMapping];
            if (nil == objMapping)
            {
                objMapping = [self.dataImporter mappingForClassNamed:[self classNameForEntityOrClassNamed:relMapping.relationshipClassName]];
            }
            
            
            id relData = [dictionaryOrArray validObjectForKey:key];
            
            // nil is OK
            if (relData != nil)
            {
                // multiple relationships
                if ([relData isKindOfClass:[NSArray class]])
                {
                    [(NSArray *)relData enumerateObjectsUsingBlock:^(id thisRelData, NSUInteger idx, BOOL *stop) {
                        
                        id theData = thisRelData;
                        if (![thisRelData isKindOfClass:[NSDictionary class]])
                        {
                            // assume it's the unique ID value
                            theData = @{ objMapping.dataIdKey : thisRelData };
                        }
                        
                        [self handleRelationshipImportOnObject:obj
                                       withRelationshipMapping:relMapping
                                                 objectMapping:objMapping
                                                       andData:theData];
                        
                    }];
                }
                else if (![relData isKindOfClass:[NSDictionary class]])
                {
                    // assume it's the unique ID value
                    relData = @{ objMapping.dataIdKey : relData };
                }
            }
            
            [self handleRelationshipImportOnObject:obj
                           withRelationshipMapping:relMapping
                                     objectMapping:objMapping
                                           andData:relData];
            
        }];
        
    }
}

- (void)handleRelationshipImportOnObject:(NSObject *)object
                 withRelationshipMapping:(RZDataManagerModelObjectRelationshipMapping *)relationshipMapping
                           objectMapping:(RZDataManagerModelObjectMapping *)objectMapping
                                 andData:(id)dictionaryOrArray
{

    NSString *dataIdKey  = objectMapping.dataIdKey;
    NSString *modelIdKey = objectMapping.modelIdPropertyName;
    NSEntityDescription       *entityDesc       = [(NSManagedObject *)object entity];
    NSRelationshipDescription *relationshipDesc = [[entityDesc relationshipsByName] objectForKey:relationshipMapping.relationshipPropertyName];

    if (relationshipDesc != nil)
    {
        if (dictionaryOrArray == nil)
        {
            // break the relationship
            SEL setter = [[object class] rz_setterForPropertyNamed:relationshipMapping.relationshipPropertyName];
            if (setter)
            {
                id value = nil;
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:setter]];
                [invocation setTarget:object];
                [invocation setSelector:setter];
                [invocation setArgument:&value atIndex:2];

                @try
                {
                    [invocation invoke];
                }
                @catch (NSException *exception)
                {
                    RZDataManagerLogError(@"Error invoking setter %@ on object of class %@: %@", NSStringFromSelector(setter), NSStringFromClass([object class]), exception);
                }

            }
            else
            {
                RZDataManagerLogError(@"Setter not found for property %@ on class %@", relationshipMapping.relationshipPropertyName, NSStringFromClass([object class]));
            }
        }
        else if ([dictionaryOrArray isKindOfClass:[NSDictionary class]])
        {
            id importedObj = nil;
            id uid         = [dictionaryOrArray validObjectForKey:dataIdKey decodeHTML:NO];
            if (uid)
            {
                // need to be able to handle many-to-many
                if (relationshipDesc.isToMany)
                {
                    // find object within other object's relationship set
                    NSSet *existingObjs = [object valueForKey:relationshipMapping.relationshipPropertyName];
                    importedObj = [self objectOfType:relationshipMapping.relationshipClassName withValue:uid forKeyPath:modelIdKey inCollection:existingObjs createNew:NO];
                    
                    // if not found in set, find globally
                    if (nil == importedObj)
                    {
                        importedObj = [self objectOfType:relationshipMapping.relationshipClassName withValue:uid forKeyPath:modelIdKey createNew:YES];
                    }
                    
                    [self.dataImporter importData:dictionaryOrArray toObject:importedObj usingMapping:objectMapping];
                    
                    if (relationshipMapping.shouldReplaceExistingRelationships)
                    {
                        NSSet *importedRelObjs = [NSSet setWithObject:importedObj];
                        [object setValue:importedRelObjs forKey:relationshipMapping.relationshipPropertyName];
                    }
                    else
                    {
                        NSMutableSet *relObjs = [[object valueForKey:relationshipMapping.relationshipPropertyName] mutableCopy];
                        if (relObjs == nil)
                        {
                            relObjs = [NSMutableSet set];
                        }
                        [relObjs addObject:importedObj];
                        [object setValue:relObjs forKey:relationshipMapping.relationshipPropertyName];
                    }
                    
                }
                else
                {
                    // create or update object
                    importedObj = [self objectOfType:relationshipMapping.relationshipClassName withValue:uid forKeyPath:modelIdKey createNew:YES];
                    [self.dataImporter importData:dictionaryOrArray toObject:importedObj usingMapping:objectMapping];
                    
                    // set relationship on other object
                    [object setValue:importedObj forKey:relationshipMapping.relationshipPropertyName];
                }
                
            }
            else
            {
                RZDataManagerLogError(@"Unique value for key %@ on entity named %@ is nil.", dataIdKey, relationshipMapping.relationshipClassName);
            }
        }
        else if ([dictionaryOrArray isKindOfClass:[NSArray class]])
        {
            // need to be able to handle many-to-many
            if (relationshipDesc.isToMany)
            {
                // optimize lookup for existing objects
                NSString     *entityName        = [self entityNameForClassOrEntityNamed:relationshipMapping.relationshipClassName];
                NSArray      *existingObjs      = [(NSSet *)[object valueForKey:relationshipMapping.relationshipPropertyName] allObjects];
                NSDictionary *existingObjsByUid = [NSDictionary dictionaryWithObjects:existingObjs forKeys:[existingObjs valueForKey:modelIdKey]];
                
                NSMutableArray *importedRelObjs = [NSMutableArray arrayWithCapacity:[(NSArray *)dictionaryOrArray count]];
                
                [(NSArray *)dictionaryOrArray enumerateObjectsUsingBlock:^(id objData, NSUInteger idx, BOOL *stop)
                 {
                     
                     id uid = [objData valueForKey:dataIdKey];
                     if (uid)
                     {
                         id importedObj = [existingObjsByUid objectForKey:uid];
                         
                         if (!importedObj)
                         {
                             importedObj = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:self.currentMoc];
                         }
                         
                         [self.dataImporter importData:objData toObject:importedObj usingMapping:objectMapping];
                         
                         [importedRelObjs addObject:importedObj];
                     }
                     
                 }];
                
                if (relationshipMapping.shouldReplaceExistingRelationships)
                {
                    [object setValue:[NSSet setWithArray:importedRelObjs] forKey:relationshipMapping.relationshipPropertyName];
                }
                else
                {
                    NSMutableSet *relObjs = [[object valueForKey:relationshipMapping.relationshipPropertyName] mutableCopy];
                    if (relObjs == nil)
                    {
                        relObjs = [NSMutableSet set];
                    }
                    [relObjs addObjectsFromArray:importedRelObjs];
                    [object setValue:relObjs forKey:relationshipMapping.relationshipPropertyName];
                }
                
                
            }
            else
            {
                RZDataManagerLogError(@"Cannot import multiple objects for to-one relationship.");
            }
            
        }
        else
        {
            RZDataManagerLogError(@"Cannot import data of type %@. Expected NSDictionary or NSArray", NSStringFromClass([dictionaryOrArray class]));
        }
    }
    else
    {
        RZDataManagerLogDebug(@"Could not find relationship %@ on entity named %@", relationshipMapping.relationshipPropertyName, entityDesc.name);
    }

}

#pragma mark - Core Data Stack

// Returns the background managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)backgroundMoc
{
    if (nil == _backgroundMoc)
    {
        NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
        if (coordinator != nil)
        {
            _backgroundMoc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            _backgroundMoc.persistentStoreCoordinator = coordinator;
        }
    }

    return _backgroundMoc;
}

// Returns the main managed object context for the application.
// If the context doesn't already exist, it is created and bound to the backgroundMoc for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (nil == _managedObjectContext)
    {
        NSManagedObjectContext *backgroundMoc = self.backgroundMoc;
        if (backgroundMoc != nil)
        {
            _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            _managedObjectContext.parentContext = backgroundMoc;
            _managedObjectContext.undoManager   = [[NSUndoManager alloc] init];
        }
    }

    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
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
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (nil == _persistentStoreCoordinator)
    {
        NSError *error = nil;
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
        
        NSDictionary *options = nil;
        
        if (self.attemptAutomaticMigration && NSSQLiteStoreType == self.persistentStoreType && self.persistentStoreURL)
        {
            options = @{ NSMigratePersistentStoresAutomaticallyOption : @(YES), NSInferMappingModelAutomaticallyOption : @(YES) };
        }
        
        if(![_persistentStoreCoordinator addPersistentStoreWithType:self.persistentStoreType configuration:nil URL:self.persistentStoreURL options:options error:&error])
        {
            RZDataManagerLogError(@"Database file is not readable with current model.");

            if (self.deleteDatabaseIfUnreadable && NSSQLiteStoreType == self.persistentStoreType && self.persistentStoreURL)
            {
                RZDataManagerLogDebug(@"Deleting database file");
                
                [[NSNotificationCenter defaultCenter] postNotificationName:RZCoreDataManagerWillDeleteInvalidDatabaseFile object:self];
                
                NSError *removeFileError = nil;
                
                if ([[NSFileManager defaultManager] removeItemAtURL:self.persistentStoreURL error:&removeFileError])
                {
                    if ([_persistentStoreCoordinator addPersistentStoreWithType:self.persistentStoreType configuration:nil URL:self.persistentStoreURL options:nil error:&error])
                    {
                        // Succeeded! - Nil out previous error to avoid abort
                        [[NSNotificationCenter defaultCenter] postNotificationName:RZCoreDataManagerDidDeleteInvalidDatabaseFile object:self];
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

- (NSString *)managedObjectModelName
{
    if (nil == _managedObjectModelName)
    {
        NSDictionary    *info        = [[NSBundle mainBundle] infoDictionary];
        NSMutableString *productName = [[info objectForKey:@"CFBundleDisplayName"] mutableCopy];
        [productName replaceOccurrencesOfString:@" " withString:@"_" options:0 range:NSMakeRange(0, productName.length)];
        [productName replaceOccurrencesOfString:@"-" withString:@"_" options:0 range:NSMakeRange(0, productName.length)];
        _managedObjectModelName = [NSString stringWithString:productName];
    }

    return _managedObjectModelName;
}

- (NSString *)persistentStoreType
{
    if (nil == _persistentStoreType)
    {
        _persistentStoreType = NSInMemoryStoreType;
    }

    return _persistentStoreType;
}

- (NSURL *)persistentStoreURL
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
    NSManagedObjectContext *moc           = self.managedObjectContext;
    NSManagedObjectContext *backgroundMoc = self.backgroundMoc;

    if (nil == moc)
    {
        return;
    }

    if ([moc hasChanges])
    {
        [self.managedObjectContext lock];

        [moc performBlockAndWait:^
        {
            NSError *error = nil;
            if (![moc save:&error])
            {
                RZDataManagerLogError(@"Error saving changes for main MOC: %@", error);
            }
        }];
        
        [self.managedObjectContext unlock];
    }

    void (^saveBackground)(void) = ^
    {
        NSError *error = nil;
        if (![backgroundMoc save:&error])
        {
            RZDataManagerLogError(@"Error saving changes to disk: %@", error);
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

- (void)resetDatabase
{
    [[NSNotificationCenter defaultCenter] postNotificationName:RZCoreDataManagerWillResetDatabaseNotification object:self];

    self.backgroundMoc              = nil;
    self.managedObjectContext       = nil;
    self.persistentStoreCoordinator = nil;

    // Database file will automatically be deleted on next lazy-load, but let's delete it anyway for security.
    BOOL shouldDeleteFile = ![self.persistentStoreType isEqualToString:NSInMemoryStoreType];

    if (shouldDeleteFile && nil != self.persistentStoreURL)
    {
        NSError *removeFileError = nil;
        if (![[NSFileManager defaultManager] removeItemAtURL:self.persistentStoreURL error:&removeFileError])
        {
            NSLog(@"Could not delete database file at url %@. Error: %@", self.persistentStoreURL.absoluteString, removeFileError);
        }
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:RZCoreDataManagerDidResetDatabaseNotification object:self];
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
