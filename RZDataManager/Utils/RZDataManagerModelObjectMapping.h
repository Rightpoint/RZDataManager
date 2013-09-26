//
//  RZDataImporterMapping.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RZDataManagerModelObjectRelationshipMapping;



@interface RZDataManagerModelObjectMapping : NSObject <NSCopying, NSMutableCopying>

@property (nonatomic, readonly, copy) NSString *dataIdKey;
@property (nonatomic, readonly, copy) NSString *modelIdPropertyName;
@property (nonatomic, readonly, copy) NSString *dateFormat;

- (id)initWithModelClass:(Class)modelClass;

- (BOOL)hasMappingDefinedForDataKey:(NSString *)key;

- (NSString *)modelPropertyNameForDataKey:(NSString *)key;

- (RZDataManagerModelObjectRelationshipMapping *)relationshipMappingForDataKey:(NSString *)key;

- (RZDataManagerModelObjectRelationshipMapping *)relationshipMappingForModelPropertyName:(NSString *)propName;

- (NSString *)importSelectorNameForDataKey:(NSString *)key;

- (NSArray *)keysToIgnore;


@end

// -----------

@interface RZDataManagerMutableModelObjectMapping : RZDataManagerModelObjectMapping

@property (nonatomic, readwrite, copy) NSString *dataIdKey;
@property (nonatomic, readwrite, copy) NSString *modelIdPropertyName;
@property (nonatomic, readwrite, copy) NSString *dateFormat;

- (void)setModelPropertyName:(NSString *)propertyName forDataKey:(NSString *)key;

- (void)setModelPropertiesForKeyNames:(NSDictionary *)mappingDict; // set ovverides all at once

- (void)setRelationshipMapping:(RZDataManagerModelObjectRelationshipMapping *)mapping forDataKey:(NSString *)key;

- (void)setImportSelectorName:(NSString *)selName forDataKey:(NSString *)key;

- (void)addKeysToIgnore:(NSArray *)keysToIgnore;

@end

// -----------

@interface RZDataManagerModelObjectRelationshipMapping : NSObject <NSCopying, NSMutableCopying>

+ (instancetype)mappingWithClassNamed:(NSString *)type
                         propertyName:(NSString *)propertyName
                  inversePropertyName:(NSString *)inverse;

- (id)initWithClassNamed:(NSString *)type
            propertyName:(NSString *)propertyName
     inversePropertyName:(NSString *)inverse;

@property (nonatomic, readonly, copy) NSString *relationshipClassName;
@property (nonatomic, readonly, copy) NSString *relationshipPropertyName;
@property (nonatomic, readonly, copy) NSString *relationshipInversePropertyName;

@property (nonatomic, readonly, copy) RZDataManagerModelObjectMapping *relatedObjectMapping;

@property (nonatomic, readonly, assign) BOOL shouldReplaceExistingRelationships;

@end

// ----------

@interface RZDataManagerMutableModelObjectRelationshipMapping : RZDataManagerModelObjectRelationshipMapping

@property (nonatomic, readwrite, copy)   RZDataManagerModelObjectMapping *relatedObjectMapping;
@property (nonatomic, readwrite, assign) BOOL shouldReplaceExistingRelationships;

@end