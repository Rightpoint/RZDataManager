//
//  DMCustomEntry.h
//  RZDataManager-Demo
//
//  Created by Nicholas Bonatsakis on 7/11/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface DMCustomEntry : NSManagedObject

@property (nonatomic, retain) NSString * uid;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * age;

@end
