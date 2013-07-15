//
//  NSObject+RZLogHelper.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/19/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "NSObject+RZLogHelper.h"

@implementation NSObject (RZLogHelper)

- (void)rz_logError:(NSString *)errorString, ...
{
    va_list args;
    va_start(args, errorString);
    NSString *formattedErrorString = [[NSString alloc] initWithFormat:errorString arguments:args];
    NSLog(@"[Error] - %@: %@", NSStringFromClass([self class]), formattedErrorString);
    va_end(args);
}

@end
