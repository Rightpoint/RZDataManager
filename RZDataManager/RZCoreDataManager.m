//
//  RZCoreDataManager.m
//
//  Created by Joe Goullaud on 2/12/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZCoreDataManager.h"
#import "NSDictionary+NonNSNull.h"
#import "RZLogHelper.h"

// Number of items to import in a single batch when importing a lot of items
#define kRZCoreDataManagerImportBatchBlockSize 50

// For storing moc reference in thread dictionary
static NSString* const kRZCoreDataManagerConfinedMocKey = @"RZCoreDataManagerConfinedMoc";

NSString * const kRZCoreDataManagerImportAsynchronously = @"RZCoreDataManagerImportAsynhcronously";

static dispatch_queue_t s_RZCoredataManagerPrivateImportQueue = nil;
static char * const s_RZCoreDataManagerPrivateImportQueueName = "com.raizlabs.RZCoreDataManagerImport";

NSString * const kRZCoreDataManagerWillResetDatabaseNotification = @"RZCoreDataManagerWillResetDatabase";
NSString * const kRZCoreDataManagerDidResetDatabaseNotification = @"RZCoreDataManagerDidResetDatabase";

@interface RZCoreDataManager ()

@property (nonatomic, readonly) NSManagedObjectContext *currentMoc;
@property (nonatomic, strong) NSManagedObjectContext *backgroundMoc;
@property (nonatomic, strong) NSMutableDictionary *classToEntityMapping;

- (id)objectForEntity:(NSString*)entity withValue:(id)value forKeyPath:(NSString*)keyPath usingMOC:(NSManagedObjectContext*)moc create:(BOOL)create;
- (id)objectForEntity:(NSString*)entity withValue:(id)value forKeyPath:(NSString*)keyPath inCollection:(id)objects usingMOC:(NSManagedObjectContext*)moc create:(BOOL)create;
- (NSArray*)objectsForEntity:(NSString*)entity matchingPredicate:(NSPredicate*)predicate usingMOC:(NSManagedObjectContext*)moc;

- (void)saveContext:(BOOL)wait;
- (NSURL*)applicationDocumentsDirectory;

- (NSString*)entityNameForClassNamed:(NSString*)className;

@end

@implementation RZCoreDataManager

- (id)init
{
    self = [super init];
    if (self){
        _classToEntityMapping = [NSMutableDictionary dictionary];
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            s_RZCoredataManagerPrivateImportQueue = dispatch_queue_create(s_RZCoreDataManagerPrivateImportQueueName, NULL);
        });
    }
    return self;
}

#pragma mark - RZDataManager Subclass

- (id)objectOfType:(NSString *)className withValue:(id)value forKeyPath:(NSString *)keyPath createNew:(BOOL)createNew
{
    return [self objectForEntity:className withValue:value forKeyPath:keyPath usingMOC:self.currentMoc create:createNew];
}

- (id)objectOfType:(NSString *)className withValue:(id)value forKeyPath:(NSString *)keyPath inCollection:(id)collection createNew:(BOOL)createNew
{
    return [self objectForEntity:className withValue:value forKeyPath:keyPath inCollection:collection usingMOC:self.currentMoc create:createNew];
}

- (id)objectsOfType:(NSString *)className matchingPredicate:(NSPredicate *)predicate
{
    return [self objectsForEntity:className matchingPredicate:predicate usingMOC:self.currentMoc];
}

- (void)importData:(NSDictionary *)data forClassNamed:(NSString *)className usingMapping:(RZDataManagerModelObjectMapping *)mapping options:(NSDictionary *)options completion:(RZDataManagerImportCompletionBlock)completion
{
    if (nil == mapping){
        mapping = [self.dataImporter mappingForClassNamed:className];
    }
    
    NSString *dataIdKey = mapping.dataIdKey;
    NSString *modelIdKey = mapping.modelIdPropertyName;
    
    if (!dataIdKey || !modelIdKey){
        RZLogDebug(@"Missing data and/or model ID keys for object of type %@", className);
        return;
    }
    
    NSMutableArray *permanentObjectIDs = [NSMutableArray array];
    
    BOOL synchronousImport = ![[options valueForKey:kRZCoreDataManagerImportAsynchronously] boolValue];
    
    [self importInBackgroundSynchronously:synchronousImport usingBlock:^{
        
        if ([data isKindOfClass:[NSDictionary class]]){
            id obj = nil;
            id uid = [data validObjectForKey:dataIdKey decodeHTML:NO];
            
            if (uid){
                obj = [self objectOfType:className withValue:uid forKeyPath:modelIdKey createNew:YES];
                if ([obj respondsToSelector:@selector(dataImportPerformImportWithData:)]) {
                    [obj dataImportPerformImportWithData:data];
                } else {
                    [self.dataImporter importData:data toObject:obj usingMapping:mapping];
                }
            }
            else{
                RZLogError(@"Unique value for key %@ on entity named %@ is nil.", dataIdKey, className);
            }
        }
        else if ([data isKindOfClass:[NSArray class]]){
            
            // optimize lookup for existing objects
            NSString *entityName = [self entityNameForClassNamed:className];
            NSEntityDescription *entityDesc = [NSEntityDescription entityForName:entityName inManagedObjectContext:self.managedObjectContext];
            NSDictionary *entityProps = [entityDesc propertiesByName];
            
            NSPropertyDescription *modelIdProp = [entityProps objectForKey:modelIdKey];
            
            if (modelIdProp != nil)
            {
                
                // Fetch only uid and object ID
                // Expression description solution from http://stackoverflow.com/a/4792331/1128820
                
                NSExpressionDescription* objectIdDesc = [[NSExpressionDescription alloc] init];
                objectIdDesc.name = @"objectID";
                objectIdDesc.expression = [NSExpression expressionForEvaluatedObject];
                objectIdDesc.expressionResultType = NSObjectIDAttributeType;
                
                NSFetchRequest *uidFetch = [NSFetchRequest fetchRequestWithEntityName:entityName];
                [uidFetch setResultType:NSDictionaryResultType];
                [uidFetch setIncludesPendingChanges:YES];
                [uidFetch setPropertiesToFetch:@[modelIdProp, objectIdDesc]];
                
                NSError *err =nil;
                NSArray *existingObjs = [self.currentMoc executeFetchRequest:uidFetch error:&err];
                
                if (err == nil )
                {
                    
                    NSDictionary *existingObjIdsByUid = [NSDictionary dictionaryWithObjects:[existingObjs valueForKey:@"objectID"] forKeys:[existingObjs valueForKey:modelIdKey]];
                    
                    NSInteger objectsRemaining = [data count];
                    NSInteger objectOffset = 0;
                    
                    while (objectsRemaining > 0)
                    {
                        
                        NSUInteger blockSize = MIN(objectsRemaining, kRZCoreDataManagerImportBatchBlockSize);
                        NSIndexSet *objectsToEnumerate = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(objectOffset, blockSize)];
                        
                        objectsRemaining -= blockSize;
                        objectOffset += blockSize;
                        
                        // Avoid bloating memory - only import a few objects at a time
                        
                        @autoreleasepool {
                            
                            NSMutableArray *importedObjects = [NSMutableArray array];
                            
                            [(NSArray*)data enumerateObjectsAtIndexes:objectsToEnumerate options:0 usingBlock:^(id objData, NSUInteger idx, BOOL *stop) {
                                
                                id uid = [objData valueForKey:dataIdKey];
                                if (uid != nil)
                                {
                                    id importedObj = nil;
                                    NSManagedObjectID *importedObjId = [existingObjIdsByUid objectForKey:uid];
                                    
                                    if (importedObjId != nil)
                                    {
                                        importedObj = [self.currentMoc objectWithID:importedObjId];
                                    }
                                    else
                                    {
                                        importedObj = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:self.currentMoc];
                                    }
                                    
                                    if ([importedObj respondsToSelector:@selector(dataImportPerformImportWithData:)]) {
                                        [importedObj dataImportPerformImportWithData:objData];
                                    } else {
                                        [self.dataImporter importData:objData toObject:importedObj];
                                    }
                                    
                                    [importedObjects addObject:importedObj];
                                }
                                
                            }];
                            
                            // Get permanent object ids for these
                            NSError *poErr = nil;
                            if (![self.currentMoc obtainPermanentIDsForObjects:importedObjects error:&poErr])
                            {
                                RZLogError(@"Error obtaining permanent object ids for newly imported objects. %@", poErr);
                            }
                            
                            [permanentObjectIDs addObjectsFromArray:[importedObjects valueForKey:@"objectID"]];
                        }

                    }

                    
                    if (options[kRZDataManagerDeleteStaleItemsPredicate] != nil)
                    {
                        NSPredicate *stalePred = options[kRZDataManagerDeleteStaleItemsPredicate];

                        // Get the actual objects from their object IDs
                        NSMutableArray *objectsToCheck = [NSMutableArray array];
                        [[existingObjIdsByUid allValues] enumerateObjectsUsingBlock:^(NSManagedObjectID * objID, NSUInteger idx, BOOL *stop) {
                            [objectsToCheck addObject:[self.currentMoc objectWithID:objID]];
                        }];
                        
                        [objectsToCheck filterUsingPredicate:stalePred];
                                                
                        NSSet *dataObjsUuids = [NSSet setWithArray:[(NSArray*)data valueForKey:dataIdKey]];
                        
                        [objectsToCheck enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            // if this model object is not present in the list of objects to import, delete it.
                            if (![dataObjsUuids containsObject:[obj valueForKey:modelIdKey]]) {
                                [self.currentMoc deleteObject:obj];
                            }
                        }];
                    }
                }
                else
                {
                    RZLogError(@"Error fetching existing objects of type %@: %@", entityName, err);
                }
            }
            else
            {
                RZLogError(@"No property named %@ found on entity named %@", modelIdKey, entityName);
            }
            
        }
        else{
            RZLogError(@"Cannot import data of type %@. Expected NSDictionary or NSArray", NSStringFromClass([data class]));
        }

                
    } completion:^(NSError *error){
        
        if (![[options objectForKey:kRZDataManagerDisableSaveAfterImport] boolValue])
        {
            [self saveContext:YES];
        }
        
        if (completion)
        {
            
            // Need to fetch object from main thread moc for completion block
            id result = nil;
            if (error == nil && ![[options valueForKey:kRZDataManagerDisableReturningObjectsFromImport] boolValue])
            {
                
                if ([data isKindOfClass:[NSDictionary class]]){
                    id uid = [data validObjectForKey:dataIdKey decodeHTML:NO];
                    result = [self objectOfType:className withValue:uid forKeyPath:modelIdKey createNew:NO];
                }
                else if ([data isKindOfClass:[NSArray class]]){
                    
                    NSMutableArray *resultArray = [NSMutableArray array];
                    [permanentObjectIDs enumerateObjectsUsingBlock:^(NSManagedObjectID *objID, NSUInteger idx, BOOL *stop)
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

- (void)importData:(id)data forRelationshipWithMapping:(RZDataManagerModelObjectRelationshipMapping *)relationshipMapping onObject:(NSObject *)object options:(NSDictionary *)options completion:(RZDataManagerImportCompletionBlock)completion
{
    NSString *objectClassName = NSStringFromClass([object class]);
    
    // use mapping attached to relationship mapping, otherwise get it from the importer
    RZDataManagerModelObjectMapping *objMapping = [relationshipMapping relatedObjectMapping];
    if (nil == objMapping)
    {
        objMapping = [self.dataImporter mappingForClassNamed:relationshipMapping.relationshipClassName];
    }
    
    NSString *dataIdKey = objMapping.dataIdKey;
    NSString *modelIdKey = objMapping.modelIdPropertyName;
    
    if (!dataIdKey || !modelIdKey){
        RZLogError(@"Missing data and/or model ID keys for object of type %@", objectClassName);
        return;
    }
    
    BOOL synchronousImport = ![[options valueForKey:kRZCoreDataManagerImportAsynchronously] boolValue];
    
    [self importInBackgroundSynchronously:synchronousImport usingBlock:^{
        
        NSEntityDescription *entityDesc = [(NSManagedObject*)object entity];
        NSRelationshipDescription *relationshipDesc = [[entityDesc relationshipsByName] objectForKey:relationshipMapping.relationshipPropertyName];
        if (relationshipDesc != nil){
            
            if ([data isKindOfClass:[NSDictionary class]]){
                
                id importedObj = nil;
                id uid = [data validObjectForKey:dataIdKey decodeHTML:NO];
                if (uid){
                    
                    // need to be able to handle many-to-many
                    if (relationshipDesc.isToMany){
                        
                        // find object within other object's relationship set
                        NSSet * existingObjs = [object valueForKey:relationshipMapping.relationshipPropertyName];
                        importedObj = [self objectOfType:relationshipMapping.relationshipClassName withValue:uid forKeyPath:modelIdKey inCollection:existingObjs createNew:NO];
                        
                        // if not found in set, find globally
                        if (nil == importedObj)
                        {
                            importedObj = [self objectOfType:relationshipMapping.relationshipClassName withValue:uid forKeyPath:modelIdKey createNew:YES];
                        }
                        
                        [self.dataImporter importData:data toObject:importedObj usingMapping:objMapping];
                        
                        if (relationshipMapping.shouldReplaceExistingRelationships){
                            NSSet *importedRelObjs = [NSSet setWithObject:importedObj];
                            [object setValue:importedRelObjs forKey:relationshipMapping.relationshipPropertyName];
                        }
                        else{
                            NSMutableSet *relObjs = [[object valueForKey:relationshipMapping.relationshipPropertyName] mutableCopy];
                            if (relObjs == nil){
                                relObjs = [NSMutableSet set];
                            }
                            [relObjs addObject:importedObj];
                            [object setValue:relObjs forKey:relationshipMapping.relationshipPropertyName];
                        }

                        
                    }
                    else{
                        
                        // create or update object
                        importedObj = [self objectOfType:relationshipMapping.relationshipClassName withValue:uid forKeyPath:modelIdKey createNew:YES];
                        [self.dataImporter importData:data toObject:importedObj usingMapping:objMapping];
                        
                        // set relationship on other object
                        [object setValue:importedObj forKey:relationshipMapping.relationshipPropertyName];
                    }
                    
                }
                else{
                    RZLogError(@"Unique value for key %@ on entity named %@ is nil.", dataIdKey, relationshipMapping.relationshipClassName);
                }
                

            }
            else if ([data isKindOfClass:[NSArray class]]){

                // need to be able to handle many-to-many
                if (relationshipDesc.isToMany){
                    
                    // optimize lookup for existing objects
                    NSString *entityName = [self entityNameForClassNamed:relationshipMapping.relationshipClassName];
                    NSArray * existingObjs = [(NSSet*)[object valueForKey:relationshipMapping.relationshipPropertyName] allObjects];                        
                    NSDictionary *existingObjsByUid = [NSDictionary dictionaryWithObjects:existingObjs forKeys:[existingObjs valueForKey:modelIdKey]];
                                        
                    NSMutableArray *importedRelObjs = [NSMutableArray arrayWithCapacity:[(NSArray*)data count]];
                                        
                    [(NSArray*)data enumerateObjectsUsingBlock:^(id objData, NSUInteger idx, BOOL *stop) {
                        
                        id uid = [objData valueForKey:dataIdKey];
                        if (uid){
                            
                            id importedObj = [existingObjsByUid objectForKey:uid];
                            
                            if (!importedObj){
                                importedObj = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:self.currentMoc];
                            }
                            
                            [self.dataImporter importData:objData toObject:importedObj usingMapping:objMapping];
                            
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
                        if (relObjs == nil){
                            relObjs = [NSMutableSet set];
                        }
                        [relObjs addObjectsFromArray:importedRelObjs];
                        [object setValue:relObjs forKey:relationshipMapping.relationshipPropertyName];
                    }
                    
                    
                }
                else{
                    RZLogError(@"Cannot import multiple objects for to-one relationship.");
                }
            
            }
            else{
                RZLogError(@"Cannot import data of type %@. Expected NSDictionary or NSArray", NSStringFromClass([data class]));
            }
        }
        else{
            RZLogDebug(@"Could not find relationship %@ on entity named %@", relationshipMapping.relationshipPropertyName, entityDesc.name);
        }
        
    } completion:^(NSError *error) {
        
        if (![[options objectForKey:kRZDataManagerDisableSaveAfterImport] boolValue])
        {
            [self saveContext:YES];
        }
        
        if (completion){
            
            // Need to fetch object from main thread moc for completion block
            id result = nil;
            if (!error){
                
                if ([data isKindOfClass:[NSDictionary class]]){
                    id uid = [data validObjectForKey:dataIdKey decodeHTML:NO];
                    result = [self objectOfType:relationshipMapping.relationshipClassName withValue:uid forKeyPath:modelIdKey createNew:NO];
                }
                else if ([data isKindOfClass:[NSArray class]]){
                    
                    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:[(NSArray*)data count]];
                    [(NSArray*)data enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
                     {
                         id uid = [obj validObjectForKey:dataIdKey decodeHTML:NO];
                         id resultEntry = [self objectOfType:relationshipMapping.relationshipClassName withValue:uid forKeyPath:modelIdKey createNew:NO];
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

- (void)importInBackgroundUsingBlock:(RZDataManagerImportBlock)importBlock completion:(RZDataManagerBackgroundImportCompletionBlock)completionBlock
{
    [self importInBackgroundSynchronously:YES usingBlock:importBlock completion:completionBlock];
}

- (void)importInBackgroundSynchronously:(BOOL)synchronously usingBlock:(RZDataManagerImportBlock)importBlock completion:(RZDataManagerBackgroundImportCompletionBlock)completionBlock;
{
    // only setup new moc if on main thread, otherwise assume we are on a background thread with associated moc
    
    
    void (^internalImportBlock)(BOOL, NSManagedObjectContext*) = ^(BOOL fromMainThread, NSManagedObjectContext *privateMoc){
        
        importBlock();
        
        NSError *error = nil;
        if(![privateMoc save:&error])
        {
            RZLogError(@"Error saving import in background: %@", error);
        }
        
        [self.managedObjectContext performBlockAndWait:^{
            [self.managedObjectContext processPendingChanges];
        }];

        
        if (fromMainThread)
        {
            dispatch_sync(dispatch_get_main_queue(), ^{

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
    
    if ([NSThread isMainThread]){
        
        if (synchronously)
        {
            dispatch_async(s_RZCoredataManagerPrivateImportQueue, ^{
               
                NSManagedObjectContext *privateMoc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
                privateMoc.parentContext = self.managedObjectContext;
                privateMoc.undoManager = nil; // should be nil already, but let's make it explicit
                
                if (![NSThread isMainThread]){
                    [[[NSThread currentThread] threadDictionary] setObject:privateMoc forKey:kRZCoreDataManagerConfinedMocKey];
                }

                internalImportBlock(YES, privateMoc);
                
            });
        }
        else
        {
            NSManagedObjectContext *privateMoc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            privateMoc.parentContext = self.managedObjectContext;
            privateMoc.undoManager = nil; // should be nil already, but let's make it explicit
            
            [privateMoc performBlock:^{
                
                if (![NSThread isMainThread]){
                    [[[NSThread currentThread] threadDictionary] setObject:privateMoc forKey:kRZCoreDataManagerConfinedMocKey];
                }
                
                internalImportBlock(YES, privateMoc);
            }];
        }

    }
    else{
        NSManagedObjectContext *moc = self.currentMoc;
        if (moc){
            
            if (moc.concurrencyType == NSPrivateQueueConcurrencyType)
            {
                // we can perform this and wait safely on a bg thread
                [moc performBlockAndWait:^{
                    internalImportBlock(NO, moc);
                }];
            }
            else
            {
                internalImportBlock(NO, moc);
            }
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

#pragma mark - Utilities

- (NSString*)entityNameForClassNamed:(NSString *)type
{
    __block NSString *entityName = [self.classToEntityMapping objectForKey:type];
    if (nil == entityName){
        
        NSDictionary *entities = [self.managedObjectModel entitiesByName];

        if ([[entities allKeys] containsObject:type]){
            entityName = type;
            [self.classToEntityMapping setObject:entityName forKey:type];
        }
        else{
            
            [entities enumerateKeysAndObjectsUsingBlock:^(NSString * eName, NSEntityDescription * eDesc, BOOL *stop) {
                
                if ([eDesc.managedObjectClassName isEqualToString:type]){
                    entityName = eName;
                    *stop = YES;
                }
                
            }];
            
            if (nil != entityName){
                [self.classToEntityMapping setObject:entityName forKey:type];
            }
            
        }
    }
    
    if (nil == entityName){
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:[NSString stringWithFormat:@"CoreData model does not contain entity or managed object class named %@", type]
                                     userInfo:nil];
    }
    
    return entityName;
}

#pragma mark - Retrieval Methods

- (id)objectForEntity:(NSString*)entity withValue:(id)value forKeyPath:(NSString*)keyPath usingMOC:(NSManagedObjectContext*)moc create:(BOOL)create
{
    // ensure this is an entity type, not the class name
    entity = [self entityNameForClassNamed:entity];
    
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

- (id)objectForEntity:(NSString *)entity withValue:(id)value forKeyPath:(NSString *)keyPath inCollection:(id)objects usingMOC:(NSManagedObjectContext *)moc create:(BOOL)create
{
    // ensure this is an entity type, not the class name
    entity = [self entityNameForClassNamed:entity];
    
    id fetchedObject = nil;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", keyPath, value];
    
    if ([objects isKindOfClass:[NSSet class]]){
        NSSet *filteredObjects = [objects filteredSetUsingPredicate:predicate];
        fetchedObject = [filteredObjects anyObject];
    }
    else if ([objects isKindOfClass:[NSArray class]]){
        NSArray *filteredObjects = [objects filteredArrayUsingPredicate:predicate];
        if (filteredObjects.count > 0){
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


- (NSArray*)objectsForEntity:(NSString*)entity matchingPredicate:(NSPredicate*)predicate usingMOC:(NSManagedObjectContext*)moc
{
    // ensure this is an entity type, not the class name
    entity = [self entityNameForClassNamed:entity];
    
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
        
        // TODO: Add auto-migrate capabilities for lightweight database migration
        
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
                RZLogError(@"Error saving changes for main MOC: %@", error);
            }
        }];
    }
    
    void (^saveBackground)(void) = ^{
        NSError *error = nil;
        if(![backgroundMoc save:&error])
        {
            RZLogError(@"Error saving changes to disk: %@", error);
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
    [[NSNotificationCenter defaultCenter] postNotificationName:kRZCoreDataManagerWillResetDatabaseNotification object:self];
    
    self.backgroundMoc = nil;
    self.managedObjectContext = nil;
    self.persistentStoreCoordinator = nil;
    
    // Database file will automatically be deleted on next lazy-load, but let's delete it anyway for security.
    BOOL shouldDeleteFile = ![self.persistentStoreType isEqualToString:NSInMemoryStoreType];
    
    if (shouldDeleteFile && nil != self.persistentStoreURL)
    {
        NSError *removeFileError = nil;
        if(![[NSFileManager defaultManager] removeItemAtURL:self.persistentStoreURL error:&removeFileError])
        {
            NSLog(@"Could not delete database file at url %@. Error: %@", self.persistentStoreURL.absoluteString, removeFileError);
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kRZCoreDataManagerDidResetDatabaseNotification object:self];
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL*)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
