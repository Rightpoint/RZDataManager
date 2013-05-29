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
    
    // since this is a test we need to load the model from our own bundle, not main bundle
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
        collection.isPublic = @(YES);
        
        for (unsigned int i=0; i<5; i++){
            DMEntry *entry = [NSEntityDescription insertNewObjectForEntityForName:@"DMEntry" inManagedObjectContext:moc];
            entry.name = names[i];
            entry.uid = [NSString stringWithFormat:@"%d", i];
            entry.date = [NSDate dateWithTimeIntervalSinceNow:i * 60];
            entry.collection = collection;
        }
    }
    
    {
        NSArray *names = @[@"Omega", @"Chi", @"Phi", @"Psi", @"Upsilon"];
        
        DMCollection *collection = [NSEntityDescription insertNewObjectForEntityForName:@"DMCollection" inManagedObjectContext:moc];
        collection.name = @"Blue";
        collection.isPublic = @(NO);
        
        for (unsigned int i=0; i<5; i++){
            DMEntry *entry = [NSEntityDescription insertNewObjectForEntityForName:@"DMEntry" inManagedObjectContext:moc];
            entry.name = names[i];
            entry.uid = [NSString stringWithFormat:@"%d", i + 5];
            entry.date = [NSDate dateWithTimeIntervalSinceNow:i * 60];
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

- (void)test101FetchSingleObject
{
    DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"0" forKeyPath:@"uid" createNew:NO];
    STAssertNotNil(entry, @"Result should not be nil");
    STAssertEqualObjects(entry.name, @"Alpha", @"Returned entry has incorrect name");
}

- (void)test102FetchObjectFromSet
{
    DMCollection *collection = [self.dataManager objectOfType:@"DMCollection" withValue:@"Red" forKeyPath:@"name" createNew:NO];
    STAssertNotNil(collection, @"Resulting collection should not be nil");
    
    if (collection){
        DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"0" forKeyPath:@"uid" inSet:collection.entries createNew:NO];
        STAssertNotNil(entry, @"Result should not be nil");
        STAssertEqualObjects(entry.name, @"Alpha", @"Returned entry has incorrect name");
    }
}

- (void)test103FetchArrayWithPredicate
{
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"collection.name == %@", @"Red"];
    NSArray *entries = [self.dataManager objectsOfType:@"DMEntry" matchingPredicate:pred];
    STAssertTrue(entries.count == 5, @"Wrong number of entries returned");
}

#pragma mark - Import tests

- (void)test200ImportObject
{
    // load plist mapping from test bundle
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *mappingUrl = [bundle URLForResource:@"DMEntryMapping" withExtension:@"plist"];
    NSDictionary *mapping = [NSDictionary dictionaryWithContentsOfURL:mappingUrl];
    
    [self.dataManager.dataImporter setMapping:mapping forClassNamed:@"DMEntry"];
    
    NSDictionary * mockData = @{@"name" : @"Omicron",
                                @"uid" : @"1000",
                                @"date" : @"2013-07-01T12:00:00Z"};
    __block BOOL finished = NO;
    [self.dataManager importData:mockData toObjectOfType:@"DMEntry" dataIdKeyPath:@"uid" modelIdKeyPath:@"uid" completion:^(id result, NSError *error)
    {
        STAssertNotNil(result, @"Result should not be nil");
        STAssertNil(error, @"Error during import: %@", error);
        
        // attempt fetch of new object
        DMEntry *entry = [self.dataManager objectOfType:@"DMEntry" withValue:@"1000" forKeyPath:@"uid" createNew:NO];
        STAssertNotNil(entry, @"Newly created entry not found");
        STAssertEqualObjects(entry.name, @"Omicron", @"Newly created entry has wrong name");
        STAssertTrue([entry.date isKindOfClass:[NSDate class]], @"Conversion of date during import failed");
        
        finished = YES;
    }];
    
    while (!finished){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}

@end
