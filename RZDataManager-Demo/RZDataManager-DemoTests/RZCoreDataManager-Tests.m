//
//  RZCoreDataManager-Tests.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/28/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZCoreDataManager-Tests.h"
#import "RZCoreDataManager.h"
#import "DMCollection.h"
#import "DMEntry.h"
#import "DMThingClass.h"
#import "DMCustomEntry.h"

@interface RZCoreDataManager_Tests ()

@property (nonatomic, strong) RZCoreDataManager *dataManager;

@end

@implementation RZCoreDataManager_Tests

- (void)setUp
{
    [super setUp];
    
    self.dataManager = [[RZCoreDataManager alloc] init];
    
    // since this is a test we need to load resources from our own bundle, not main bundle
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *url = [bundle URLForResource:@"RZDataManager_Test" withExtension:@"momd"];
    
    self.dataManager.managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    self.dataManager.persistentStoreType = NSInMemoryStoreType;
    
    // Insert a few dummy objects and collections
    NSManagedObjectContext *moc = [self.dataManager managedObjectContext];
    
    {
        NSArray *names = @[@"Alpha", @"Beta", @"Gamma", @"Delta", @"Epsilon"];
        
        DMCollection *collection = [NSEntityDescription insertNewObjectForEntityForName:@"DMCollection" inManagedObjectContext:moc];
        collection.name = @"Red";
        
        for (unsigned int i=0; i<5; i++){
            DMEntry *entry = [NSEntityDescription insertNewObjectForEntityForName:@"DMEntry" inManagedObjectContext:moc];
            entry.name = names[i];
            entry.uid = [NSString stringWithFormat:@"%d", i];
            entry.createdDate = [NSDate dateWithTimeIntervalSinceNow:i * 60];
            entry.popularity = @((float)rand()/RAND_MAX);
            entry.collection = collection;
        }
    }
    
    {
        NSArray *names = @[@"Omega", @"Chi", @"Phi", @"Psi", @"Upsilon"];
        
        DMCollection *collection = [NSEntityDescription insertNewObjectForEntityForName:@"DMCollection" inManagedObjectContext:moc];
        collection.name = @"Blue";
        
        for (unsigned int i=0; i<5; i++){
            DMEntry *entry = [NSEntityDescription insertNewObjectForEntityForName:@"DMEntry" inManagedObjectContext:moc];
            entry.name = names[i];
            entry.uid = [NSString stringWithFormat:@"%d", i + 5];
            entry.createdDate = [NSDate dateWithTimeIntervalSinceNow:i * 60];
            entry.popularity = @((float)rand()/RAND_MAX);
            entry.collection = collection;
        }
    }
    
    [self.dataManager saveData:YES];
}

- (void)tearDown
{
    [super tearDown];
    
    self.dataManager = nil;
}

#pragma mark - Fetch tests

- (void)test100FetchSingleObject
{
    DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"0" forKeyPath:@"uid" createNew:NO];
    STAssertNotNil(entry, @"Result should not be nil");
    STAssertEqualObjects(entry.name, @"Alpha", @"Returned entry has incorrect name");
}


- (void)test101FetchArrayWithPredicate
{
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"collection.name == %@", @"Red"];
    NSArray *entries = [self.dataManager objectsOfType:@"DMEntry" matchingPredicate:pred];
    STAssertTrue(entries.count == 5, @"Wrong number of entries returned");
}

#pragma mark - Import tests

- (void)test200ImportObject
{
    NSDictionary * mockData = @{@"name" : @"Omicron",
                                @"uid" : @"1000",
                                @"popularity" : @(0.5),
                                @"testFloat" : @(1.0f),
                                @"testDouble" : @(1.0),
                                @"testUInt" : @(-1), // should wrap back to 0xFFFFFFFF
                                @"testInt" : @(-1),
                                @"testShort" : @(-1),
                                @"testUShort" : @(-1), // should wrap back to 0xFFFF
                                @"testLongLong" : @(-1),
                                @"testULongLong" : @(-1), // should wrap back to 0xFFFFFFFFFFFFFFFF
                                @"testBool" : @(YES),
                                @"date" : @"2013-07-01T12:00:00Z"};
    
    __block BOOL finished = NO;
    [self.dataManager importData:mockData forClassNamed:@"DMEntry" options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)} completion:^(id result, NSError *error)
    {
        STAssertNotNil(result, @"Result should not be nil");
        STAssertNil(error, @"Error during import: %@", error);
        
        STAssertEqualObjects([(NSManagedObject*)result managedObjectContext], self.dataManager.managedObjectContext, @"Returned object should be from main thread's MOC");
        
        // attempt clean fetch of new object
        DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1000" forKeyPath:@"uid" createNew:NO];

        STAssertNotNil(entry, @"Newly created entry not found");
        STAssertEqualObjects(entry.name, @"Omicron", @"Newly created entry has wrong name");
        STAssertTrue([entry.createdDate isKindOfClass:[NSDate class]], @"Conversion of date during import failed");
        
        STAssertEquals(entry.testFloat, 1.0f, @"Float conversion failed");
        STAssertEquals(entry.testDouble, 1.0, @"Double conversion failed");
        STAssertEquals(entry.testUInt, (unsigned int)0xFFFFFFFF, @"Unsigned int conversion failed");
        STAssertEquals(entry.testInt, (int)-1, @"Int conversion failed");
        STAssertEquals(entry.testShort, (SInt16)-1, @"Short conversion failed");
        STAssertEquals(entry.testUShort, (UInt16)0xFFFF, @"Unsigned short conversion failed");
        STAssertEquals(entry.testLongLong, (SInt64)-1, @"Long long conversion failed");
        STAssertEquals(entry.testULongLong, (UInt64)0xFFFFFFFFFFFFFFFF, @"Unsigned long long conversion failed");
        STAssertEquals(entry.testBool, (BOOL)YES, @"Bool conversion failed");

        finished = YES;
    }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test200bImportObject_importOverride
{
    NSDictionary *mockData = @{ @"uid": @"1000",
                                @"subDict": @{
                                        @"1": @"Omicron",
                                        @"2": @21
                                        } };
    
    __block BOOL finished = NO;
    [self.dataManager importData:mockData forClassNamed:@"DMCustomEntry" options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)} completion:^(id result, NSError *error)
     {
         STAssertNotNil(result, @"Result should not be nil");
         STAssertNil(error, @"Error during import: %@", error);
                  
         // attempt clean fetch of new object
         DMCustomEntry *entry = [self.dataManager objectOfType:@"DMCustomEntry" withValue:@"1000" forKeyPath:@"uid" createNew:NO];
         
         STAssertNotNil(entry, @"Newly created entry not found");
         STAssertEqualObjects(entry.name, @"Omicron", @"Newly created entry has wrong name");
         STAssertEqualObjects(entry.age, @21, @"Newly created entry has wrong age.");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}


- (void)test2001SetImportedPropertyToNil
{
    // Importing from JSON with null value should set property to nil
    NSDictionary * mockData = @{@"uid" : @"0",
                                @"createdDate" : [NSNull null]};
    
    __block BOOL finished = NO;
    [self.dataManager importData:mockData forClassNamed:@"DMEntry" options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)} completion:^(id result, NSError *error)
     {
         STAssertNotNil(result, @"Result should not be nil");
         STAssertNil(error, @"Error during import: %@", error);
         
         STAssertEqualObjects([(NSManagedObject*)result managedObjectContext], self.dataManager.managedObjectContext, @"Returned object should be from main thread's MOC");
         
         // attempt clean fetch of new object
         DMEntry *entry = (DMEntry*)result;
         STAssertNil(entry.createdDate, @"Date was not correctly set to nil");
         
         finished = YES;
     }];
    
    while (!finished)
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test201ImportMultipleObjects
{
    NSArray * mockData = @[ @{@"name" : @"Omicron",
                                @"uid" : @"1000",
                                @"popularity" : @(0.5),
                                @"date" : @"2013-07-01T12:00:00Z"},
                            
                                @{@"name" : @"Pi",
                                  @"uid" : @"1001",
                                  @"popularity" : @(0.8),
                                  @"date" : @"2013-07-02T08:00:22Z"}
                            ];
    
    // create existing model obj, not in import list, should not be touched. 
    DMEntry *existingEntry = [self.dataManager objectOfType:@"DMEntry" withValue:@"0" forKeyPath:@"uid" createNew:YES];
    existingEntry.uid = @"4444411";
    existingEntry.name = @"Delete Me";
    existingEntry.popularity = @(0.5);
    existingEntry.createdDate = [NSDate date];
    [self.dataManager saveData:YES];
    
    __block BOOL finished = NO;
    [self.dataManager importData:mockData forClassNamed:@"DMEntry" options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)} completion:^(id result, NSError *error)
     {
         STAssertNotNil(result, @"Result should not be nil");
         STAssertNil(error, @"Error during import: %@", error);
         
         STAssertTrue([result isKindOfClass:[NSArray class]], @"Result should be array");
                           
         // attempt clean fetch of new objects
         DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1000" forKeyPath:@"uid" createNew:NO];
         
         STAssertNotNil(entry, @"Newly created entry not found");
         STAssertEqualObjects(entry.name, @"Omicron", @"Newly created entry has wrong name");
         STAssertTrue([entry.createdDate isKindOfClass:[NSDate class]], @"Conversion of date during import failed");
         
         entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1001" forKeyPath:@"uid" createNew:NO];
         
         STAssertNotNil(entry, @"Newly created entry not found");
         STAssertEqualObjects(entry.name, @"Pi", @"Newly created entry has wrong name");
         STAssertTrue([entry.createdDate isKindOfClass:[NSDate class]], @"Conversion of date during import failed");
         
         // look up existing entry, should still be there
         DMEntry *existEntry = [self.dataManager objectOfType:@"DMEntry" withValue:@"4444411" forKeyPath:@"uid" createNew:NO];
         STAssertNotNil(existEntry, @"Existing entry was not present.");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test201bImportMultipleObjects_deleteStale
{
    NSArray * mockData = @[ @{@"name" : @"Omicron",
                              @"uid" : @"1000",
                              @"popularity" : @(0.5),
                              @"date" : @"2013-07-01T12:00:00Z"},
                            
                            @{@"name" : @"Pi",
                              @"uid" : @"1001",
                              @"popularity" : @(0.8),
                              @"date" : @"2013-07-02T08:00:22Z"}
                            ];
    
    // create existing model obj, not in import list, should be deleted.
    DMEntry *existingEntry = [self.dataManager objectOfType:@"DMEntry" withValue:@"0" forKeyPath:@"uid" createNew:YES];
    existingEntry.uid = @"4444411";
    existingEntry.name = @"Delete Me";
    existingEntry.popularity = @(0.5);
    existingEntry.createdDate = [NSDate date];
    [self.dataManager saveData:YES];
    
    // predicate = all dates > ref date, effectivly all entries. 
    NSDictionary *options = @{RZDataManagerDeleteStaleItemsPredicateOptionKey : [NSPredicate predicateWithFormat:@"createdDate > %@", [NSDate dateWithTimeIntervalSinceReferenceDate:0]],
            RZDataManagerReturnObjectsFromImportOptionKey : @(YES)};
    __block BOOL finished = NO;
    [self.dataManager importData:mockData forClassNamed:@"DMEntry" options:options completion:^(id result, NSError *error)
     {
         STAssertNotNil(result, @"Result should not be nil");
         STAssertNil(error, @"Error during import: %@", error);
         
         STAssertTrue([result isKindOfClass:[NSArray class]], @"Result should be array");
                  
         // attempt clean fetch of new objects
         DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1000" forKeyPath:@"uid" createNew:NO];
         
         STAssertNotNil(entry, @"Newly created entry not found");
         STAssertEqualObjects(entry.name, @"Omicron", @"Newly created entry has wrong name");
         STAssertTrue([entry.createdDate isKindOfClass:[NSDate class]], @"Conversion of date during import failed");
         
         entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1001" forKeyPath:@"uid" createNew:NO];
         
         STAssertNotNil(entry, @"Newly created entry not found");
         STAssertEqualObjects(entry.name, @"Pi", @"Newly created entry has wrong name");
         STAssertTrue([entry.createdDate isKindOfClass:[NSDate class]], @"Conversion of date during import failed");
         
         // look up the entry that should have been deleted
         DMEntry *staleEntry = [self.dataManager objectOfType:@"DMEntry" withValue:@"4444411" forKeyPath:@"uid" createNew:NO];
         STAssertNil(staleEntry, @"Stale object was not deleted");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test201cImportMultipleObjects_importOverride
{
    NSArray *mockData = @[ @{ @"uid": @"1000",
                              @"subDict": @{
                                      @"1": @"Omicron",
                                      @"2": @21
                                      } },
                           
                           @{ @"uid": @"101",
                              @"subDict": @{
                                      @"1": @"Delta",
                                      @"2": @27
                                      } }
                           ];
    
    __block BOOL finished = NO;
    [self.dataManager importData:mockData forClassNamed:@"DMCustomEntry" options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)} completion:^(id result, NSError *error)
     {
         STAssertNotNil(result, @"Result should not be nil");
         STAssertNil(error, @"Error during import: %@", error);
         
         STAssertTrue([result isKindOfClass:[NSArray class]], @"Result should be array");
         
         // attempt clean fetch of new objects
         DMCustomEntry *entry = [self.dataManager objectOfType:@"DMCustomEntry" withValue:@"1000" forKeyPath:@"uid" createNew:NO];
         
         STAssertNotNil(entry, @"Newly created entry not found");
         STAssertEqualObjects(entry.name, @"Omicron", @"Newly created entry has wrong name");
         STAssertEqualObjects(entry.age, @21, @"Newly created entry has wrong age.");
         
         entry = [self.dataManager objectOfType:@"DMCustomEntry" withValue:@"101" forKeyPath:@"uid" createNew:NO];
         
         STAssertNotNil(entry, @"Newly created entry not found");
         STAssertEqualObjects(entry.name, @"Delta", @"Newly created entry has wrong name");
         STAssertEqualObjects(entry.age, @27, @"Newly created entry has wrong age.");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test202ImportObjectWithOverriddenMapping
{
    NSDictionary * mockData = @{@"mahNameIs" : @"Omicron",
                                @"uid" : @"1000",
                                @"popularity" : @(0.5),
                                @"testFloat" : @(1.0f),
                                @"testDouble" : @(1.0),
                                @"testUInt" : @(-1), // should wrap back to 0xFFFFFFFF
                                @"testInt" : @(-1),
                                @"testShort" : @(-1),
                                @"testUShort" : @(-1), // should wrap back to 0xFFFF
                                @"testLongLong" : @(-1),
                                @"testULongLong" : @(-1), // should wrap back to 0xFFFFFFFFFFFFFFFF
                                @"testBool" : @(YES),
                                @"date" : @"2013-07-01T12:00:00Z"};
    
    
    // Use a custom mapping for the name property    
    __block BOOL finished = NO;
    [self.dataManager importData:mockData forClassNamed:@"DMEntry" keyMappings:@{ @"mahNameIs" : @"name" } options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)}  completion:^(id result, NSError *error)
     {
         STAssertNotNil(result, @"Result should not be nil");
         STAssertNil(error, @"Error during import: %@", error);
         
         STAssertEqualObjects([(NSManagedObject*)result managedObjectContext], self.dataManager.managedObjectContext, @"Returned object should be from main thread's MOC");
         
         // attempt clean fetch of new object
         DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1000" forKeyPath:@"uid" createNew:NO];
         
         STAssertNotNil(entry, @"Newly created entry not found");
         STAssertEqualObjects(entry.name, @"Omicron", @"Newly created entry has wrong name");
         STAssertTrue([entry.createdDate isKindOfClass:[NSDate class]], @"Conversion of date during import failed");
         
         STAssertEquals(entry.testFloat, 1.0f, @"Float conversion failed");
         STAssertEquals(entry.testDouble, 1.0, @"Double conversion failed");
         STAssertEquals(entry.testUInt, (unsigned int)0xFFFFFFFF, @"Unsigned int conversion failed");
         STAssertEquals(entry.testInt, (int)-1, @"Int conversion failed");
         STAssertEquals(entry.testShort, (SInt16)-1, @"Short conversion failed");
         STAssertEquals(entry.testUShort, (UInt16)0xFFFF, @"Unsigned short conversion failed");
         STAssertEquals(entry.testLongLong, (SInt64)-1, @"Long long conversion failed");
         STAssertEquals(entry.testULongLong, (UInt64)0xFFFFFFFFFFFFFFFF, @"Unsigned long long conversion failed");
         STAssertEquals(entry.testBool, (BOOL)YES, @"Bool conversion failed");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test203ImportObjectWithRelationship
{
    NSDictionary * mockData = @{@"name" : @"Omicron",
                                @"uid" : @"1000",
                                @"date" : @"2013-07-01T12:00:00Z",
                                @"collection" : @"Red"};
    
    __block BOOL finished = NO;
    [self.dataManager importData:mockData forClassNamed:@"DMEntry" options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)}  completion:^(id result, NSError *error)
     {
         STAssertNotNil(result, @"Result should not be nil");
         STAssertNil(error, @"Error during import: %@", error);
         
         STAssertEqualObjects([(NSManagedObject*)result managedObjectContext], self.dataManager.managedObjectContext, @"Returned object should be from main thread's MOC");
         
         // attempt clean fetch of collection containing new object
         DMCollection *redcollection = [self.dataManager objectOfType:@"DMCollection" withValue:@"Red" forKeyPath:@"name" createNew:NO];
         STAssertNotNil(redcollection, @"Collection not found");
         STAssertTrue(redcollection.entries.count == 6, @"New entry not correctly added");
         
         DMEntry *newEntry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1000" forKeyPath:@"uid" inCollection:redcollection.entries createNew:NO];
         STAssertNotNil(newEntry, @"New entry not found in collection");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test204ImportObjectsWithNewRelationships
{
    // import a few new collections, each with a few entries
    
    NSDictionary *yellowCollection = @{
                                       @"name" : @"Yellow",
                                       @"entries" :
                                           @[
                                               @{
                                                   @"name" : @"Omicron",
                                                   @"uid" : @"1000"
                                                },
                                               @{
                                                   @"name" : @"Pi",
                                                   @"uid" : @"1001"
                                                }
                                            ]
                                       };
    
    NSDictionary *greenCollection = @{
                                       @"name" : @"Green",
                                       @"entries" :
                                           @[
                                               @{
                                                   @"name" : @"Mu",
                                                   @"uid" : @"1002"
                                                },
                                               @{
                                                   @"name" : @"Nu",
                                                   @"uid" : @"1003"
                                                }
                                            ]
                                       };
    
    __block BOOL finished = NO;
    
    [self.dataManager importData:@[yellowCollection, greenCollection]
                      forClassNamed:@"DMCollection"
                         options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)}
                      completion:^(id result, NSError *error)
    {
        STAssertTrue(error == nil, @"Import error occured: %@", error);
        
        // returned result should be array with two objects
        STAssertTrue([result isKindOfClass:[NSArray class]], @"Result should be an array");
        STAssertTrue([result count] == 2, @"Resulting array should have two objects");
        
        // first object should be collection named "Yellow" with two entries
        DMCollection *collection = [(NSArray*)result objectAtIndex:0];
        STAssertEqualObjects([collection name], @"Yellow", @"Returned collection has incorrect name");
        STAssertTrue(collection.entries.count == 2, @"Returned collection has wrong number of entries");
        DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1000" forKeyPath:@"uid" inCollection:collection.entries createNew:NO];
        STAssertNotNil(entry, @"Imported related entry not found");

        
        [collection.entries enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            STAssertTrue([[obj name] isEqualToString:@"Omicron"] || [[obj name] isEqualToString:@"Pi"], @"Imported entry for new collection has incorrect name");
        }];
        
        // second object should be collection named "Green" with two entries
        collection = [(NSArray*)result objectAtIndex:1];
        STAssertEqualObjects([collection name], @"Green", @"Returned collection has incorrect name");
        STAssertTrue(collection.entries.count == 2, @"Returned collection has wrong number of entries");
        entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1002" forKeyPath:@"uid" inCollection:collection.entries createNew:NO];
        STAssertNotNil(entry, @"Imported related entry not found");

        [collection.entries enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            STAssertTrue([[obj name] isEqualToString:@"Mu"] || [[obj name] isEqualToString:@"Nu"], @"Imported entry for new collection has incorrect name");
        }];
        
        
        finished = YES;
    }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    
}

- (void)test205ImportAndUpdateObjectsForRelationship
{
    NSDictionary *redCollection = @{
                                       @"name" : @"Red",
                                       @"entries" :
                                           @[
                                               @{
                                                   @"uid" : @"0",
                                                   @"popularity" : @(0.5) // update alpha popularity to 0.5
                                                },
                                               @{
                                                   @"name" : @"Pi",
                                                   @"uid" : @"1001"
                                                }
                                            ]
                                       };
    
    
    __block BOOL finished = NO;
    
    [self.dataManager importData:redCollection
                      forClassNamed:@"DMCollection"
                         options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)}
                      completion:^(id result, NSError *error)
     {
         STAssertTrue(error == nil, @"Import error occured: %@", error);
         
         // result object should be collection named "Red"
         DMCollection *collection = (DMCollection*)result;
         STAssertEqualObjects([collection name], @"Red", @"Returned collection has incorrect name");
         STAssertTrue(collection.entries.count == 6, @"Returned collection has wrong number of entries");

         DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"0" forKeyPath:@"uid" inCollection:collection.entries createNew:NO];
         STAssertNotNil(entry, @"Red entry not found");
         STAssertTrue(entry.popularity.doubleValue == 0.5, @"Entry not updated correctly");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}


- (void)test2051OverwriteRelationships
{
    NSDictionary *redCollection = @{
                                    @"name" : @"Red",
                                    @"entries" :
                                        @[
                                            @{
                                                @"uid" : @"0",
                                                @"popularity" : @(0.5)
                                            },
                                            @{
                                                @"name" : @"Pi",
                                                @"uid" : @"1001"
                                            }
                                        ]
                                    };
    
    
    __block BOOL finished = NO;
    
    // This time all other entries should be removed from the "Red" collection
    // The configuration is a bit tedious here, it may be worth trying to streamline if this is a common use case
    RZDataManagerMutableModelObjectMapping *mapping = [[self.dataManager mappingForClassNamed:@"DMCollection"] mutableCopy];
    RZDataManagerMutableModelObjectRelationshipMapping *relMapping = [[mapping relationshipMappingForDataKey:@"entries"] mutableCopy];
    relMapping.shouldReplaceExistingRelationships = YES;
    [mapping setRelationshipMapping:relMapping forDataKey:@"entries"];
    
    [self.dataManager importData:redCollection
                      forClassNamed:@"DMCollection"
                    usingMapping:mapping
                         options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)}
                      completion:^(id result, NSError *error)
     {
         STAssertTrue(error == nil, @"Import error occured: %@", error);
         
         // result object should be collection named "Red"
         DMCollection *collection = (DMCollection*)result;
         STAssertEqualObjects([collection name], @"Red", @"Returned collection has incorrect name");
         
         // this time only two entries should exist - we overwrote all of the existing relationships
         STAssertEquals(collection.entries.count, (NSUInteger)2, @"Returned collection has wrong number of entries");
         
         DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"0" forKeyPath:@"uid" inCollection:collection.entries createNew:NO];
         STAssertNotNil(entry, @"Red entry not found");
         STAssertEquals(entry.popularity.doubleValue, 0.5, @"Entry not updated correctly");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test2052ImportRelationshipWithCustomMapping
{
    NSDictionary *redCollection = @{
                                    @"name" : @"Red",
                                    @"entries" :
                                            @{
                                                @"whatsmyname" : @"Pi",
                                                @"uid" : @"1001"
                                            }
                                    };
    
    
    __block BOOL finished = NO;
    
    // The configuration is a bit tedious here, it may be worth trying to streamline if this is a common use case
    
    // Get default mapping for "DMCollection"
    RZDataManagerMutableModelObjectMapping *collectionMapping = [[self.dataManager mappingForClassNamed:@"DMCollection"] mutableCopy];
    
    // Get default mapping for "DMEntry"
    RZDataManagerMutableModelObjectMapping *entryMapping = [[self.dataManager mappingForClassNamed:@"DMEntry"] mutableCopy];
    
    // Set custom mapping for whatsmyname -> name on "DMEntry"
    [entryMapping setModelPropertyName:@"name" forDataKey:@"whatsmyname"];
    
    // Get relationship mapping for entries on "DMCollection"
    RZDataManagerMutableModelObjectRelationshipMapping *entryRelMapping = [[collectionMapping relationshipMappingForDataKey:@"entries"] mutableCopy];
    
    // Set the overridden "DMEntry" mapping
    entryRelMapping.relatedObjectMapping = entryMapping;
    
    // Set the overriden entries relationship mapping
    [collectionMapping setRelationshipMapping:entryRelMapping forDataKey:@"entries"];
        
    [self.dataManager importData:redCollection
                      forClassNamed:@"DMCollection"
                    usingMapping:collectionMapping
                         options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)}
                      completion:^(id result, NSError *error)
     {
         STAssertTrue(error == nil, @"Import error occured: %@", error);
         
         // result object should be collection named "Red"
         DMCollection *collection = (DMCollection*)result;
         STAssertEqualObjects([collection name], @"Red", @"Returned collection has incorrect name");
         
         // Should have one extra entry
         STAssertEquals(collection.entries.count, (NSUInteger)6, @"Returned collection has wrong number of entries");
         
         DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1001" forKeyPath:@"uid" inCollection:collection.entries createNew:NO];
         STAssertNotNil(entry, @"Pi entry not found");
         STAssertEqualObjects(entry.name, @"Pi", @"Entry not updated correctly");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test2053RemoveRelationships
{
        
    // Should remove all entries from "Red" collection
    NSDictionary *redCollection = @{
                                    @"name" : @"Red",
                                    @"entries" : [NSNull null]
                                    };
    
    
    __block BOOL finished = NO;
    
    [self.dataManager importData:redCollection
                      forClassNamed:@"DMCollection"
                            options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)}
                        completion:^(id result, NSError *error)
     {
         STAssertTrue(error == nil, @"Import error occured: %@", error);
         
         // result object should be collection named "Red"
         DMCollection *collection = (DMCollection*)result;
         STAssertEqualObjects([collection name], @"Red", @"Returned collection has incorrect name");
         STAssertEquals(collection.entries.count, (NSUInteger)0, @"Failed to break relationship for entries");

         // Ensure inverse relationship is correctly broken
         DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"0" forKeyPath:@"uid" createNew:NO];
         STAssertNotNil(entry, @"Entry should still exist");
         STAssertNil(entry.collection, @"Entry should not have a collection anymore");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}


- (void)test206ImportObjectWithDifferentEntityNameFromClass
{
    
    // The class name is DMThingClass, but the entity is DMThing. This should be handled by RZCoreDataManager.

    NSDictionary * thingData = @{ @"id" : @"12345",
                                  @"attribute1" : @"whatup",
                                  @"attribute2" : @"withdat" };
    
    __block BOOL finished = NO;
    
    [self.dataManager importData:thingData
                      forClassNamed:@"DMThingClass"
                         options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)}
                      completion:^(id result, NSError *error)
     {
         STAssertTrue(error == nil, @"Import error occured: %@", error);
         
         // is it a DMThingClass?
         STAssertTrue([result isKindOfClass:[DMThingClass class]], @"Returned object is wrong type");
         STAssertEqualObjects([result myIdentifier], @"12345", @"Failed to import identifier attribute");
         STAssertEqualObjects([result attribute1], @"whatup", @"Failed to import attribute1");
         STAssertEqualObjects([result attribute2], @"withdat", @"Failed to import attribute2");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test2061SetAttributeToNilWithCustomSetter
{
    
    // The class name is DMThingClass, but the entity is DMThing. This should be handled by RZCoreDataManager.
    
    NSDictionary * thingData = @{ @"id" : @"12345",
                                  @"attribute1" : @"whatup",
                                  @"attribute2" : @"withdat"};
    
    __block BOOL finished = NO;
    
    [self.dataManager importData:thingData
                      forClassNamed:@"DMThingClass"
                         options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)}
                      completion:^(id result, NSError *error)
     {
         STAssertTrue(error == nil, @"Import error occured: %@", error);
         
         // is it a DMThingClass?
         STAssertTrue([result isKindOfClass:[DMThingClass class]], @"Returned object is wrong type");
         STAssertEqualObjects([result myIdentifier], @"12345", @"Failed to import identifier attribute");
         STAssertEqualObjects([result attribute1], @"whatup", @"Failed to import attribute1");
         STAssertEqualObjects([result attribute2], @"withdat", @"Failed to import attribute2");
         
         // Import data for a transient property
         NSDictionary *someThingData = @{@"someOtherProperty" : @"something"};

         [self.dataManager.dataImporter importData:someThingData toObject:result];
         
         STAssertEqualObjects([result someOtherProperty], @"something", @"Failed to import someOtherProperty");
         
         // Now clear out the value to nil.
         // DMThingClass defines a custom setter name for this property so this tests whether the importer can handle that.
         NSDictionary * moreThingData = @{ @"someOtherProperty" : [NSNull null] };
         
         [self.dataManager.dataImporter importData:moreThingData toObject:result];
         
         STAssertNil([result someOtherProperty], @"Failed to nil out someOtherProperty");

         finished = YES;
         
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test207AbandonChanges
{
    
    // Importing a new object will not persist the data to the persistent store. You must call saveData: to do that.
    
    NSDictionary * mockData = @{@"name" : @"Omicron",
                                @"uid" : @"1000",
                                @"date" : @"2013-07-01T12:00:00Z",
                                @"collection" : @"Red"};
    
    __block BOOL finished = NO;
    [self.dataManager importData:mockData forClassNamed:@"DMEntry" options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)}  completion:^(id result, NSError *error)
     {
         STAssertNotNil(result, @"Result should not be nil");
         STAssertNil(error, @"Error during import: %@", error);
         
         STAssertEqualObjects([(NSManagedObject*)result managedObjectContext], self.dataManager.managedObjectContext, @"Returned object should be from main thread's MOC");
         
         // attempt clean fetch of collection containing new object
         DMCollection *redcollection = [self.dataManager objectOfType:@"DMCollection" withValue:@"Red" forKeyPath:@"name" createNew:NO];
         STAssertNotNil(redcollection, @"Collection not found");
         STAssertTrue(redcollection.entries.count == 6, @"New entry not correctly added");
         
         DMEntry *newEntry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1000" forKeyPath:@"uid" inCollection:redcollection.entries createNew:NO];
         STAssertNotNil(newEntry, @"New entry not found in collection");
         
         STAssertNoThrow([self.dataManager saveData:YES], @"Failed to save context");
         
         // reset context and fetch again
         [self.dataManager.managedObjectContext reset];
         
         newEntry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1000" forKeyPath:@"uid" createNew:NO];
         STAssertNotNil(newEntry, @"New entry not found in database after persist and reset");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    
    
    // This time, import an object, discard changes, it should not be present in main moc
    mockData = @{@"name" : @"Pi",
                 @"uid" : @"1001",
                 @"date" : @"2013-07-01T12:00:00Z",
                 @"collection" : @"Red"};
    
    finished = NO;
    [self.dataManager importData:mockData forClassNamed:@"DMEntry" options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES), RZDataManagerSaveAfterImportOptionKey : @(NO)} completion:^(id result, NSError *error)
     {
         STAssertNotNil(result, @"Result should not be nil");
         STAssertNil(error, @"Error during import: %@", error);
         
         STAssertEqualObjects([(NSManagedObject*)result managedObjectContext], self.dataManager.managedObjectContext, @"Returned object should be from main thread's MOC");
         
         // attempt clean fetch of collection containing new object
         DMCollection *redcollection = [self.dataManager objectOfType:@"DMCollection" withValue:@"Red" forKeyPath:@"name" createNew:NO];
         STAssertNotNil(redcollection, @"Collection not found");
         STAssertTrue(redcollection.entries.count == 7, @"New entry not correctly added");
         
         DMEntry *newEntry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1001" forKeyPath:@"uid" inCollection:redcollection.entries createNew:NO];
         STAssertNotNil(newEntry, @"New entry not found in collection");
         
         STAssertNoThrow([self.dataManager discardChanges], @"Failed to discard changes to context");
         
         newEntry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1001" forKeyPath:@"uid" createNew:NO];
         STAssertNil(newEntry, @"New entry should not exist after discarding changes");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test208HugeImport
{
    // Make a whole lot of data to import
    NSInteger numIterations = 2000;
    NSMutableArray *dataToImport = [NSMutableArray arrayWithCapacity:numIterations];
    for (NSInteger i=0; i<numIterations; i++)
    {
        [dataToImport addObject:@{  @"name" : [NSString stringWithFormat:@"Item %d", i+1],
                                    @"uid"  : [NSString stringWithFormat:@"%d", i + 10000],
                                    @"collection" : @"Red"
                                }];
    }
    
    // Import and don't return imported objects
    __block BOOL finished = NO;
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    // import and don't return objects
    [self.dataManager importData:dataToImport forClassNamed:@"DMEntry" options:nil completion:^(id result, NSError *error)
     {
         STAssertNil(result, @"Result should be nil - we didn't pass the option to return objects");
         STAssertNil(error, @"Error during import: %@", error);
         
         NSTimeInterval executionTime = [NSDate timeIntervalSinceReferenceDate] - startTime;
         NSLog(@"First import finished in %.3f seconds", executionTime);
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    
    // Do another big ol' import
    dataToImport = [NSMutableArray arrayWithCapacity:numIterations];
    for (NSInteger i=0; i<numIterations; i++)
    {
        [dataToImport addObject:@{  @"name" : [NSString stringWithFormat:@"Item %d", i+50001],
         @"uid"  : [NSString stringWithFormat:@"%d", i + 50000],
         @"collection" : @"Red"
         }];
    }
    
    finished = NO;
    startTime = [NSDate timeIntervalSinceReferenceDate];
    // import and don't return objects
    [self.dataManager importData:dataToImport forClassNamed:@"DMEntry" options:nil completion:^(id result, NSError *error)
     {
         STAssertNil(result, @"Result should be nil - we did't pass the option to return objects");
         STAssertNil(error, @"Error during import: %@", error);
         
         NSTimeInterval executionTime = [NSDate timeIntervalSinceReferenceDate] - startTime;
         NSLog(@"Second import finished in %.3f seconds", executionTime);
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test_replaceItems
{
    NSFetchRequest *allItemFetch = [NSFetchRequest fetchRequestWithEntityName:@"DMEntry"];
    NSArray *results = [self.dataManager.managedObjectContext executeFetchRequest:allItemFetch error:NULL];
    
    STAssertTrue(results.count == 10, @"Should be multiple items in DB at start");
    
    
    NSArray * mockData = @[ @{@"name" : @"Omicron",
                              @"uid" : @"1000"},
                            @{@"name" : @"Pi",
                              @"uid" : @"1001"} ];
                            
    
    __block BOOL finished = NO;
    [self.dataManager importData:mockData forClassNamed:@"DMEntry" options:@{RZDataManagerReplaceItemsOptionKey : @(YES)} completion:^(id result, NSError *error)
     {
         NSFetchRequest *postImportItemFetch = [NSFetchRequest fetchRequestWithEntityName:@"DMEntry"];
         NSArray *postImportResults = [self.dataManager.managedObjectContext executeFetchRequest:postImportItemFetch error:NULL];

         STAssertTrue(postImportResults.count == 2, @"Should only two items in database post import");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test_deleteResolution
{
    __block BOOL finished = NO;
    
    [self.dataManager performDataOperationInBackgroundUsingBlock:^(RZDataManager *manager, id context) {
        
        DMEntry *bgEntry = [self.dataManager objectOfType:@"DMEntry" withValue:@"0" forKeyPath:@"uid" createNew:NO];
        STAssertNotNil(bgEntry, @"Entry should exist in child moc");
        
        bgEntry.name = @"yoohoo";
        
        // delete object on main moc
        dispatch_sync(dispatch_get_main_queue(), ^{
            DMEntry *mainEntry = [self.dataManager objectOfType:@"DMEntry" withValue:@"0" forKeyPath:@"uid" createNew:NO];
            STAssertNotNil(mainEntry, @"Zero entry should exist");
            [self.dataManager.managedObjectContext deleteObject:mainEntry];
            [self.dataManager saveData:YES];
        });


    } completion:^(NSError *error) {
        
        // verify there's a duplicate
        NSFetchRequest *df = [NSFetchRequest fetchRequestWithEntityName:@"DMEntry"];
        df.predicate = [NSPredicate predicateWithFormat:@"uid == %@", @"0"];
        
        NSArray *deletedResults = [self.dataManager.managedObjectContext executeFetchRequest:df error:NULL];
        STAssertTrue(deletedResults.count == 0, @"Deleted item is still here...");
    
        finished = YES;
    }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    
}

#pragma mark - Dictionary conversion test

- (void)test300ConvertToDictionary
{
    NSDictionary * mockData = @{
                                @"name" : @"Omicron",
                                @"uid" : @"1000",
                                @"collection" : @"Red",
                                @"popularity" : @(0.5),
                                @"testFloat" : @(1.0f),
                                @"testDouble" : @(1.0),
                                @"testUInt" : @(-1), // should wrap back to 0xFFFFFFFF
                                @"testInt" : @(-1),
                                @"testShort" : @(-1),
                                @"testUShort" : @(-1), // should wrap back to 0xFFFF
                                @"testLongLong" : @(-1),
                                @"testULongLong" : @(-1), // should wrap back to 0xFFFFFFFFFFFFFFFF
                                @"testBool" : @(YES),
                                @"date" : @"2013-07-01T12:00:00Z"
                                };
    
    __block BOOL finished = NO;
    [self.dataManager importData:mockData forClassNamed:@"DMEntry" options:@{RZDataManagerReturnObjectsFromImportOptionKey : @(YES)}  completion:^(id result, NSError *error)
     {
         STAssertNotNil(result, @"Result should not be nil");
         STAssertNil(error, @"Error during import: %@", error);
         
         if (result){
             
             // Verify result in console
             // TODO: Equality check
             
             NSDictionary * entryDict = [self.dataManager dictionaryFromModelObject:result];
             NSLog(@"%@",entryDict);
         }
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }

}

@end
