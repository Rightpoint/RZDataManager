//
//  RZDataImporterMapping.h
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 6/4/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RZDataManagerModelObjectRelationshipMapping;

@interface RZDataManagerModelObjectMapping : NSObject <NSCopying>

@property (nonatomic, copy) NSString *dataIdKey;
@property (nonatomic, copy) NSString *modelIdPropertyName;
@property (nonatomic, copy) NSString *dateFormat;
@property (nonatomic, copy) NSArray  *ignoreKeys;

- (id)initWithModelClass:(Class)modelClass;

- (void)applyOptions:(NSDictionary*)options;

- (NSString*)modelPropertyNameForDataKey:(NSString*)key;
- (void)setModelPropertyName:(NSString*)propertyName forDataKey:(NSString*)key;

- (RZDataManagerModelObjectRelationshipMapping*)relationshipMappingForDataKey:(NSString*)key;
- (RZDataManagerModelObjectRelationshipMapping*)relationshipMappingForModelPropertyName:(NSString*)propName;
- (void)setRelationshipMapping:(RZDataManagerModelObjectRelationshipMapping*)mapping forDataKey:(NSString*)key;

- (NSString*)importSelectorNameForDataKey:(NSString*)key;
- (void)setImportSelectorName:(NSString*)selName forDataKey:(NSString*)key;

@end

@interface RZDataManagerModelObjectRelationshipMapping : NSObject <NSCopying>

+ (RZDataManagerModelObjectRelationshipMapping*)mappingWithObjectType:(NSString*)type propertyName:(NSString*)propertyName inversePropertyName:(NSString*)inverse;

@property (nonatomic, copy) NSString * relationshipObjectType;
@property (nonatomic, copy) NSString * relationshipPropertyName;
@property (nonatomic, copy) NSString * relationshipInversePropertyName;
@property (nonatomic, copy) NSDictionary * options;

@end
