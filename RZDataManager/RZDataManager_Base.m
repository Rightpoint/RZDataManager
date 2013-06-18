//
//  RZDataManager_Base.m
//  RZDataManager-Demo
//
//  Created by Nick Donaldson on 5/28/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataManager_Base.h"
#import "NSObject+RZPropertyUtils.h"

@interface RZDataManager ()

- (NSException*)abstractMethodException:(SEL)selector;

@end

@implementation RZDataManager
{
    RZDataImporter * _dataImporter;
}

+ (instancetype)defaultManager
{
    static RZDataManager * s_defaultManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_defaultManager = [[self alloc] init];
    });
    return s_defaultManager;
}

// Allocate data importer via lazy load
- (RZDataImporter*)dataImporter
{
    if (nil == _dataImporter){
        _dataImporter = [[RZDataImporter alloc] init];
        _dataImporter.dataManager = self;
    }
    return _dataImporter;
}

- (NSURL*)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSException*)abstractMethodException:(SEL)selector
{
    return [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(selector)]
                                 userInfo:nil];
}

#pragma mark - Data Manager public methods

- (id)objectOfType:(NSString*)type withValue:(id)value forKeyPath:(NSString*)keyPath createNew:(BOOL)createNew
{
    @throw [self abstractMethodException:_cmd];
}

- (id)objectOfType:(NSString*)type
         withValue:(id)value
        forKeyPath:(NSString*)keyPath
      inCollection:(id)collection
         createNew:(BOOL)createNew
{
    @throw [self abstractMethodException:_cmd];
}

- (id)objectsOfType:(NSString*)type matchingPredicate:(NSPredicate*)predicate
{
    @throw [self abstractMethodException:_cmd];
}

- (void)importData:(id)data objectType:(NSString*)type
           options:(NSDictionary *)options
        completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}


- (void)importData:(id)data objectType:(NSString *)type
   forRelationship:(NSString *)relationshipKey
          onObject:(id)otherObject
           options:(NSDictionary *)options
        completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}

- (void)importData:(id)data objectType:(NSString *)type
     dataIdKeyPath:(NSString *)dataIdKeyPath
    modelIdKeyPath:(NSString *)modelIdKeyPath
   forRelationship:(NSString *)relationshipKey
          onObject:(id)otherObject
        completion:(RZDataManagerImportCompletionBlock)completion
{
    @throw [self abstractMethodException:_cmd];
}

- (void)importInBackgroundUsingBlock:(RZDataManagerImportBlock)importBlock completion:(void (^)(NSError *))completionBlock
{
    @throw [self abstractMethodException:_cmd];
}

// optional, default does nothing
- (void)saveData:(BOOL)synchronous
{
    NSLog(@"RZDataManager: saveData: is not implemented.");
}

- (void)discardChanges
{
    NSLog(@"RZDataManager: discardChanges is not implemented.");
}

#pragma mark - Miscellaneous

- (NSDictionary*)dictionaryFromModelObject:(NSObject *)object
{
    RZDataManagerModelObjectMapping * mapping = [self.dataImporter mappingForClassNamed:NSStringFromClass([object class])];
    
    NSArray * propertyNames = [[object class] getPropertyNames];
    NSMutableDictionary * dictionaryRepresentation = [NSMutableDictionary dictionaryWithCapacity:propertyNames.count];
    
    [propertyNames enumerateObjectsUsingBlock:^(NSString * propName, NSUInteger idx, BOOL *stop) {
        
        NSString * propType = [[object class] dataTypeForPropertyNamed:propName];

        if (rz_isScalarDataType(propType))
        {
            // TODO: For now this will only work if the getter name is not overridden. Need to handle that case in the future (in property utils).
            SEL getter = NSSelectorFromString(propName);
            
            NSNumber * numberValue = nil;
            
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:getter]];
            [invocation setTarget:object];
            [invocation setSelector:getter];
            
            if ([propType isEqualToString:kRZDataManagerTypeChar]){
                char charValue;
                [invocation invoke];
                [invocation getReturnValue:&charValue];
                numberValue = @(charValue);
            }
            else if ([propType isEqualToString:kRZDataManagerTypeInt]){
                NSInteger intValue;
                [invocation invoke];
                [invocation getReturnValue:&intValue];
                numberValue = @(intValue);
            }
            else if ([propType isEqualToString:kRZDataManagerTypeUnsignedInt]){
                NSUInteger uIntValue;
                [invocation invoke];
                [invocation getReturnValue:&uIntValue];
                numberValue = @(uIntValue);
            }
            else if ([propType isEqualToString:kRZDataManagerTypeShort]){
                SInt16 shortValue;
                [invocation invoke];
                [invocation getReturnValue:&shortValue];
                numberValue = @(shortValue);
            }
            else if ([propType isEqualToString:kRZDataManagerTypeUnsignedShort]){
                UInt16 uShortValue;
                [invocation invoke];
                [invocation getReturnValue:&uShortValue];
                numberValue = @(uShortValue);
            }
            else if ([propType isEqualToString:kRZDataManagerTypeLong]){
                SInt32 longValue;
                [invocation invoke];
                [invocation getReturnValue:&longValue];
                numberValue = @(longValue);
            }
            else if ([propType isEqualToString:kRZDataManagerTypeUnsignedLong]){
                UInt32 uLongValue;
                [invocation invoke];
                [invocation getReturnValue:&uLongValue];
                numberValue = @(uLongValue);
            }
            else if ([propType isEqualToString:kRZDataManagerTypeLongLong]){
                SInt64 longLongValue;
                [invocation invoke];
                [invocation getReturnValue:&longLongValue];
                numberValue = @(longLongValue);
            }
            else if ([propType isEqualToString:kRZDataManagerTypeUnsignedLongLong]){
                UInt64 uLongLongValue;
                [invocation invoke];
                [invocation getReturnValue:&uLongLongValue];
                numberValue = @(uLongLongValue);
            }
            else if ([propType isEqualToString:kRZDataManagerTypeFloat]){
                float floatValue;
                [invocation invoke];
                [invocation getReturnValue:&floatValue];
                numberValue = @(floatValue);
            }
            else if ([propType isEqualToString:kRZDataManagerTypeDouble]){
                double doubleValue;
                [invocation invoke];
                [invocation getReturnValue:&doubleValue];
                numberValue = @(doubleValue);
            }
            
            if (nil != numberValue){
                [dictionaryRepresentation setObject:numberValue forKey:propName];
            }
        }
        else if ([mapping relationshipMappingForModelPropertyName:propName])
        {
            // for relationships, don't serialze the entire other object - this could lead to infinite recursion
            // just convert the unique identifier key/value pairs
            RZDataManagerModelObjectRelationshipMapping * relMapping = [mapping relationshipMappingForModelPropertyName:propName];
            RZDataManagerModelObjectMapping * otherObjMapping = [self.dataImporter mappingForClassNamed:relMapping.relationshipObjectType];
            
            id propValue = nil;
            @try {
                propValue = [object valueForKey:propName];
            }
            @catch (NSException *exception) {
                NSLog(@"RZDataImporter: Object of type %@ does not respond to key %@", NSStringFromClass([object class]), propName);
            }
            
            id (^IdSerializerBlock)(id obj) = ^id(id obj){
                
                id otherObjUid = nil;
                @try {
                    otherObjUid = [obj valueForKey:otherObjMapping.modelIdPropertyName];
                }
                @catch (NSException *exception) {
                    NSLog(@"RZDataImporter: Object of type %@ does not respond to key %@", relMapping.relationshipObjectType, otherObjMapping.modelIdPropertyName);
                }
                
                return otherObjUid;
                
            };
            
            if ([propValue isKindOfClass:[NSArray class]])
            {
                NSMutableArray * relArray = [NSMutableArray arrayWithCapacity:[propValue count]];
                [(NSArray*)propValue enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                   
                    id otherObjUid = IdSerializerBlock(obj);
                    
                    if (otherObjUid){
                        [relArray addObject:@{otherObjMapping.dataIdKey : otherObjUid}];
                    }
                 
                }];
                
                [dictionaryRepresentation setObject:relArray forKey:propName];
            }
            else if ([propValue isKindOfClass:[NSSet class]])
            {
                NSMutableSet * relSet = [NSMutableSet setWithCapacity:[propValue count]];
                [(NSSet*)propValue enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                    
                    id otherObjUid = IdSerializerBlock(obj);
                    
                    if (otherObjUid){
                        [relSet addObject:@{otherObjMapping.dataIdKey : otherObjUid}];
                    }
                    
                }];
                
                [dictionaryRepresentation setObject:relSet forKey:propName];

            }
            else if (propValue != nil)
            {
                id otherObjUid = IdSerializerBlock(propValue);
                
                if (otherObjUid){
                    [dictionaryRepresentation setObject:@{otherObjMapping.dataIdKey : otherObjUid} forKey:propName];
                }
            }
        }
        else{
            id propValue = nil;
            @try {
                propValue = [object valueForKey:propName];
            }
            @catch (NSException *exception) {
                NSLog(@"RZDataImporter: Object of type %@ does not respond to key %@", NSStringFromClass([object class]), propName);
            }
            if (propValue){
                [dictionaryRepresentation setObject:propValue forKey:propName];
            }
        }
        
    }];
        
    return dictionaryRepresentation;
}

@end
