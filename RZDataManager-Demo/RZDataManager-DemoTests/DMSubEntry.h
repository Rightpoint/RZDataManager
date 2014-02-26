//
//  DMSubEntry.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 2/26/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "DMBaseEntry.h"

@class DMEntry;

@interface DMSubEntry : DMBaseEntry

@property (nonatomic, retain) NSString * subAttribute;
@property (nonatomic, retain) DMEntry *entry;

@end
