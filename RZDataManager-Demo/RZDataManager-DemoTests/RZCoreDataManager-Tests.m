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
    
    NSError *err = nil;
    [moc save:&err];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Fetch tests

- (void)test100FetchSingleObject
{
    DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"0" forKeyPath:@"uid" createNew:NO options:nil];
    STAssertNotNil(entry, @"Result should not be nil");
    STAssertEqualObjects(entry.name, @"Alpha", @"Returned entry has incorrect name");
}


- (void)test101FetchArrayWithPredicate
{
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"collection.name == %@", @"Red"];
    NSArray *entries = [self.dataManager objectsOfType:@"DMEntry" matchingPredicate:pred options:nil];
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
    [self.dataManager importData:mockData objectType:@"DMEntry" options:nil completion:^(id result, NSError *error)
    {
        STAssertNotNil(result, @"Result should not be nil");
        STAssertNil(error, @"Error during import: %@", error);
        
        STAssertEqualObjects([(NSManagedObject*)result managedObjectContext], self.dataManager.managedObjectContext, @"Returned object should be from main thread's MOC");
        
        // attempt clean fetch of new object
        DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1000" forKeyPath:@"uid" createNew:NO options:nil];

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

- (void)test201ImportObjectWithOverriddenMapping
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
    RZDataManagerModelObjectMapping * mapping = [self.dataManager.dataImporter mappingForClassNamed:@"DMEntry"];
    [mapping setModelPropertyName:@"name" forDataKey:@"mahNameIs"];
    
    NSDictionary *opts = @{ RZDataManagerCustomMappingKey : mapping };
    
    __block BOOL finished = NO;
    [self.dataManager importData:mockData objectType:@"DMEntry" options:opts completion:^(id result, NSError *error)
     {
         STAssertNotNil(result, @"Result should not be nil");
         STAssertNil(error, @"Error during import: %@", error);
         
         STAssertEqualObjects([(NSManagedObject*)result managedObjectContext], self.dataManager.managedObjectContext, @"Returned object should be from main thread's MOC");
         
         // attempt clean fetch of new object
         DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1000" forKeyPath:@"uid" createNew:NO options:nil];
         
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

- (void)test202ImportObjectWithRelationship
{
    NSDictionary * mockData = @{@"name" : @"Omicron",
                                @"uid" : @"1000",
                                @"date" : @"2013-07-01T12:00:00Z",
                                @"collection" : @"Red"};
    
    __block BOOL finished = NO;
    [self.dataManager importData:mockData objectType:@"DMEntry" options:nil completion:^(id result, NSError *error)
     {
         STAssertNotNil(result, @"Result should not be nil");
         STAssertNil(error, @"Error during import: %@", error);
         
         STAssertEqualObjects([(NSManagedObject*)result managedObjectContext], self.dataManager.managedObjectContext, @"Returned object should be from main thread's MOC");
         
         // attempt clean fetch of collection containing new object
         DMCollection *redcollection = [self.dataManager objectOfType:@"DMCollection" withValue:@"Red" forKeyPath:@"name" createNew:NO options:nil];
         STAssertNotNil(redcollection, @"Collection not found");
         STAssertTrue(redcollection.entries.count == 6, @"New entry not correctly added");
         
//         DMEntry *newEntry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1000" forKeyPath:@"uid" inSet:redcollection.entries createNew:NO options:nil];
//         STAssertNotNil(newEntry, @"New entry not found in collection");
         
         finished = YES;
     }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)test202ImportObjectsWithNewRelationships
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
                      objectType:@"DMCollection"
                         options:nil
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
        
        [collection.entries enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            STAssertTrue([[obj name] isEqualToString:@"Omicron"] || [[obj name] isEqualToString:@"Pi"], @"Imported entry for new collection has incorrect name");
        }];
        
        finished = YES;
    }];
    
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    
}

@end
