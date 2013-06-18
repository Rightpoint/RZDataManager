//
//  RZDataMangerConstants.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - RZDataManager options dictionary keys

// overrides for mapping

OBJC_EXTERN NSString * const RZDataManagerImportDataIdKey;              // override default data key(path) for uniquely identifying object
OBJC_EXTERN NSString * const RZDataManagerImportModelIdPropertyName;    // override default property name for uniquely identifying object
OBJC_EXTERN NSString * const RZDataManagerImportDateFormat;             // override default date format for import
OBJC_EXTERN NSString * const RZDataManagerImportIgnoreKeys;             // override keys to ignore
OBJC_EXTERN NSString * const RZDataManagerImportKeyMappings;            // override default mappings for keypaths->property names

// other options

OBJC_EXTERN NSString * const RZDataManagerOverwriteRelationships;     // if true, will remove any related objects not present in imported data

#pragma mark - Misc

OBJC_EXTERN NSString* const kRZDataManagerUTCDateFormat;

