//
//  DMEntry.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/28/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DMCollection;

@interface DMEntry : NSManagedObject

@property (nonatomic, retain) NSString  * name;
@property (nonatomic, retain) NSString  * uid;
@property (nonatomic, retain) NSNumber  * popularity;
@property (nonatomic, retain) NSDate    * createdDate;
@property (nonatomic, retain) DMCollection *collection;

// extra datatypes for testing importer conversion
@property (nonatomic, assign) float         testFloat;
@property (nonatomic, assign) double        testDouble;
@property (nonatomic, assign) NSInteger     testInt;
@property (nonatomic, assign) NSUInteger    testUInt;
@property (nonatomic, assign) SInt16        testShort;
@property (nonatomic, assign) UInt16        testUShort;
@property (nonatomic, assign) SInt64        testLongLong;
@property (nonatomic, assign) UInt64        testULongLong;
@property (nonatomic, assign) BOOL          testBool;

@end