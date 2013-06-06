//
//  DMThingClass.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/6/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "RZDataManagerModelObject.h"

@interface DMThingClass : NSManagedObject <RZDataManagerModelObject>

@property (nonatomic, retain) NSString * attribute1;
@property (nonatomic, retain) NSString * attribute2;
@property (nonatomic, retain) NSString * myIdentifier;

@end
