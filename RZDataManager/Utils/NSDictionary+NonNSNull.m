//
//  NSDictionary+NonNSNull.m
//
//  Created by Craig Spitzkoff on 2/2/12.
//  Copyright (c) 2012 Raizlabs Corporation. All rights reserved.
//

#import "NSDictionary+NonNSNull.h"
#import "NSString+HTMLEntities.h"

@implementation NSDictionary (NonNSNull)

-(id) validObjectForKey:(id)aKey
{
    return [self validObjectForKey:aKey decodeHTML:YES];
}

-(id) validObjectForKey:(id)aKey decodeHTML:(BOOL)shouldDecode
{
    id obj = [self objectForKey:aKey];
    if (obj == [NSNull null]) {
        obj = nil;
    }
    
    if (shouldDecode && [obj isKindOfClass:[NSString class]])
    {
        obj = [(NSString*)obj stringByDecodingHTMLEntities];
    }
    
    return obj;
}

-(id) validObjectForKeyPath:(id)aKeyPath
{
    return [self validObjectForKeyPath:aKeyPath decodeHTML:YES];
}

-(id) validObjectForKeyPath:(id)aKeyPath decodeHTML:(BOOL)shouldDecode
{
    id obj = [self valueForKeyPath:aKeyPath];
    if (obj == [NSNull null]) {
        obj = nil;
    }
    
    if (shouldDecode && [obj isKindOfClass:[NSString class]])
    {
        obj = [(NSString*)obj stringByDecodingHTMLEntities];
    }
    
    return obj;
}

-(id) numberForKey:(id)aKey
{
    id object = [self validObjectForKey:aKey];
    
    if([object isKindOfClass:[NSString class]])
    {
        NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        object = [formatter numberFromString:object];
    }
    else if(![object isKindOfClass:[NSNumber class]])
    {
        object = nil;
    }
    
    return object;
}

@end
