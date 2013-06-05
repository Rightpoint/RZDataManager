//
//  RZDataManagerModelObject.h
//  RZDataManager
//
//  Created by Nick Donaldson on 5/30/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RZDataMangerConstants.h"
#import "RZDataManagerModelObjectMapping.h"

@protocol RZDataManagerModelObject <NSObject>

//! The default key by which incoming data is uniquely identified
+ (NSString*)defaultDataIdKey;

//! The property by which the model object is uniquely identified
+ (NSString*)modelIdPropertyName;

@optional

//! Date format for string-date conversions
+ (NSString*)dataImportDateFormat;

//! Return a dictionary of data keys mapped to property names, if keys/names differ for a particular mapping.
/*!
    Example:
 
    Returning the dictionary below would map incoming data for key "image" to property "imagePath", etc
 
    @{
        "image" : "imagePath",
        "id"    : "uniqueId"
    }
*/
+ (NSDictionary*)dataImportKeyMappings;

//! Return a dictionary of RZDataManagerModelObjectRelationshipMapping objects keyed by property name
/*!
 
    NOTE: This is handled automatically by RZCoreDataManager for NSManagedObject subclasses. If this method is implemented, it will be ignored.
 
    Example:
 
    Let current object have type "RZDepartment". 
    This method would return the following dictionary
 
    @{ "employees" : [RZDataManagerModelObjectRelationshipMapping mappingWithObjectType:@"RZEmployee" inversePropertyName:@"department"] }
*/

+ (NSDictionary*)dataImportRelationshipKeyMappings;

//! Return a dictionary of data keys mapped to the name of a selector (as string) to call for custom import logic
+ (NSDictionary*)dataImportCustomSelectorKeyMappings;

//! Keys to ignore when importing data
+ (NSArray*)dataImportIgnoreKeys;


//! Implement this method to prepare the object to be updated with new data
- (void)prepareForImportFromData:(NSDictionary*)data;

//! Implement this method to finalize the import and send "updated" notifications
- (void)finalizeImportFromData:(NSDictionary*)data;


@end
