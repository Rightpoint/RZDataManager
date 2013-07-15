//
//  NSObject+RZLogHelper.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/19/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (RZLogHelper)

- (void)rz_logError:(NSString*)errorString, ...;

@end
