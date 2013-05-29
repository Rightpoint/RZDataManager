//
//  RZDataImporter.h
//
//  Created by Nick Donaldson on 2/26/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RZDataManager;

@protocol RZDataImporterModelObject <NSObject>

@optional

//! Implement this method to return a cached object matching the passed-in unique key-value pair
+ (id)cachedObjectWithUniqueValue:(id)uniqueValue forKeyPath:(id)key;

//! Implement this method to prepare the object to be updated with new data
- (void)prepareForImportFromData:(NSDictionary*)data;

//! Implement this method to finalize the import and send "updated" notifications
- (void)finalizeImportFromData:(NSDictionary*)data;

@end

@class RZDataImporterDiffInfo;

@interface RZDataImporter : NSObject

//! Weak reference to parent Data Manager
@property (nonatomic, weak) RZDataManager *dataManager;

//! Set to override on importer-level whether should decode HTML entities from strings (defaults to NO)
@property (nonatomic, assign) BOOL shouldDecodeHTML;

//! Externally set a mapping dictionary for a particular class
- (void)setMapping:(NSDictionary*)mapping forClassNamed:(NSString*)className;

//! Import data from a dictionary to an object based on a provided (or TBD: assumed) mapping
- (void)importData:(NSDictionary*)data toObject:(NSObject<RZDataImporterModelObject>*)object;

//! Update objects passed in with data passed in, and optionally return array of objects that will be added and removed from array passed in. Basically does a diff-update of model object collection with incoming data set.
/*!
    objects - array of objects to update. Should be of type objClass.
    objClass - type of objects in objects array.
    dataIdKeyPath - key path to value uniquely identifying object in raw dictionary
    modelIdKeyPath - key path to value uniquely identifying model object. Value will be compared against value for dataIdKey in raw data
    data - either an array of dictionaries or a dictionary containing data with which to update objects
    diffInfo - object containing arrays of added, moved, and removed objects 
*/
- (RZDataImporterDiffInfo*)updateObjects:(NSArray*)objects
                                 ofClass:(Class)objClass
                                withData:(id)data
                           dataIdKeyPath:(NSString*)dataIdKeyPath
                          modelIdKeyPath:(NSString*)modelIdKeyPath;


@end


@interface RZDataImporterDiffInfo : NSObject

// Objects which were added and the indices at which they were added
@property (strong, nonatomic) NSMutableArray* addedObjects;
@property (strong, nonatomic) NSMutableArray* insertionIndices;

// Objects which were removed
@property (strong, nonatomic) NSMutableArray* removedObjects;

// Objects which were moved and to which indices they were moved (in the final array)
@property (strong, nonatomic) NSMutableArray* movedObjects;
@property (strong, nonatomic) NSMutableArray* moveIndices;

@end