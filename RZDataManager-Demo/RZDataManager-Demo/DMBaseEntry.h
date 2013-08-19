//
//  DMBaseEntry.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 8/15/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface DMBaseEntry : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * uid;

@end
