//
//  RZDataManagerModelObject.h
//  RZDataManager
//
//  Created by Nick Donaldson on 5/30/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RZDataMangerConstants.h"

@protocol RZDataManagerModelObject <NSObject>

//! The default key by which incoming data is uniquely identified
+ (NSString*)defaultDataIdKey;

//! The property by which the model object is uniquely identified
+ (NSString*)modelIdPropertyName;

@optional

//! Return a dictionary of data keys mapped to property names, if keys/names differ for a particular mapping. Supports period-delimited keypaths.
/*!
    Example:
 
    Returning the dictionary below would map incoming data for key "image" to property "imagePath", etc
 
    @{
        "image" : "imagePath",
        "id"    : "uniqueId"
    }
*/
+ (NSDictionary*)dataImportKeyMappings;

//! Return a dictionary of property names representing object relationships, mapped to the object type and inverse relationship property name.
/*!

    Example:
 
    Let current object have type "RZDepartment". 
    This method would return the following dictionary (key names as constants)
 
    @{
        "employees" : @{
            kRZDataManagerRelationshipObjectType : "RZEmployee",
            kRZDataManagerRelationshipInverse : "department"
        }
    }
*/
+ (NSDictionary*)relationshipImportKeyMappings;

//! Return a dictionary of data keys mapped to the name of a selector (as string) to call for custom import logic
+ (NSDictionary*)customSelectorImportKeyMappings;

//! Keys to ignore when importing data
+ (NSArray*)ignoreKeyPaths;


//! Implement this method to prepare the object to be updated with new data
- (void)prepareForImportFromData:(NSDictionary*)data;

//! Implement this method to finalize the import and send "updated" notifications
- (void)finalizeImportFromData:(NSDictionary*)data;


@end
