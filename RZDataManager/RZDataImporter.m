//
//  RZDataImporter.m
//
//  Created by Nick Donaldson on 2/26/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataImporter.h"
#import "RZDataManager_Base.h"

#import "RZDataManagerModelObjectMapping.h"
#import "RZDataMangerConstants.h"

#import "NSDictionary+NonNSNull.h"
#import "NSString+HTMLEntities.h"
#import "NSObject+RZPropertyUtils.h"

@interface RZDataImporter ()

@property (nonatomic, strong) NSMutableDictionary *modelMappings;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSNumberFormatter *numberFormatter;

- (RZDataManagerModelObjectMapping*)createMappingForClassNamed:(NSString*)className;

- (void)importValue:(id)value toObject:(NSObject<RZDataManagerModelObject>*)object fromKeyPath:(NSString*)keyPath withMapping:(RZDataManagerModelObjectMapping*)mapping;

- (void)setPropertyValue:(id)value onObject:(NSObject<RZDataManagerModelObject>*)object fromKeyPath:(NSString*)keyPath withMapping:(RZDataManagerModelObjectMapping*)mapping;

- (SEL)setterFromPropertyName:(NSString*)propertyName;

- (id)convertValue:(id)value toType:(NSString*)conversionType withFormat:(NSString*)format;

@end

@implementation RZDataImporter

- (id)init
{
    self = [super init];
    if (self){
        
        self.shouldDecodeHTML = NO;
        
        self.modelMappings = [NSMutableDictionary dictionaryWithCapacity:16];
        
        self.dateFormatter = [[NSDateFormatter alloc] init];
        self.numberFormatter = [[NSNumberFormatter alloc] init];
        self.numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        self.defaultDateFormat = kRZDataManagerUTCDateFormat;
    }
    return self;
}

#pragma mark - Public

- (RZDataManagerModelObjectMapping*)mappingForClassNamed:(NSString *)className
{
    RZDataManagerModelObjectMapping *mapping = nil;
    
    if (nil != className){
        // First, check cache
        mapping = [self.modelMappings objectForKey:className];
        
        // If not in cache, build mapping from object class
        if (mapping == nil){
            mapping = [self createMappingForClassNamed:className];
        }

        if (mapping != nil){
            [self.modelMappings setObject:mapping forKey:className];
        }
    }
    
    return mapping;
}


- (void)importData:(NSDictionary *)data toObject:(NSObject<RZDataManagerModelObject>*)object
{
    // TODO: Maybe raise exception here
    if (object && data){
        
        NSString *className = NSStringFromClass([object class]);
        
        if ([object conformsToProtocol:@protocol(RZDataManagerModelObject)]){
            RZDataManagerModelObjectMapping *mapping = [self mappingForClassNamed:className];
            if (mapping != nil){
                [self importData:data toObject:object usingMapping:mapping];
            }
        }
        else{
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:[NSString stringWithFormat:@"Class %@ does not conform to RZDataManagerModelObject protocol", className]
                                         userInfo:nil];
        }

    }
}


- (RZDataImporterDiffInfo*)diffInfoForObjects:(NSArray*)objects
                                     withData:(id)data
                                dataIdKeyPath:(NSString*)dataIdKeyPath
                               modelIdKeyPath:(NSString*)modelIdKeyPath
{
    
    RZDataImporterDiffInfo *diffInfo = [[RZDataImporterDiffInfo alloc] init];
    
    NSArray *dataDicts = nil;
    if ([data isKindOfClass:[NSArray class]]){
        dataDicts = data;
    }
    else if ([data isKindOfClass:[NSDictionary class]]){
        dataDicts = @[data];
    }
    
    if (dataDicts != nil){
        
        // Update and insert new items
        if (dataDicts.count > 0){
            
            [dataDicts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj isKindOfClass:[NSDictionary class]]){
                    
                    NSDictionary* dataDict = obj;
                    id uniqueValue = nil;
                    NSArray* matchingItems = nil;
                    
                    BOOL itemExists = NO;
                    
                    // try to find matching object
                    if (dataIdKeyPath != nil && modelIdKeyPath != nil){
                        
                        uniqueValue = [dataDict validObjectForKeyPath:dataIdKeyPath decodeHTML:self.shouldDecodeHTML];
                        if (uniqueValue != nil){
                            
                            // find existing item
                            NSPredicate *matchPred = [NSPredicate predicateWithFormat:@"%K == %@", modelIdKeyPath, uniqueValue];
                            matchingItems = [objects filteredArrayUsingPredicate:matchPred];
                            itemExists = (matchingItems.count > 0);
                        }
                    }
                    
                    // create new object if necessary
                    if (!itemExists){
                        [diffInfo.insertedObjectIndices addObject:@(idx)];
                    }
                    else if (matchingItems.count == 1){
                        [diffInfo.movedObjectIndices addObject:@(idx)];
                    }
                }
            }];

        }
        
        // Enumerate items that aren't in array
        NSArray *currentUniqueVals = [dataDicts valueForKeyPath:dataIdKeyPath];
        [objects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id objValue = [obj valueForKeyPath:modelIdKeyPath];
            if (![currentUniqueVals containsObject:objValue]){
                [diffInfo.removedObjectIndices addObject:@(idx)];
            }
        }];
    }
    
    return diffInfo;
}


#pragma mark - Private

- (RZDataManagerModelObjectMapping*)createMappingForClassNamed:(NSString *)className
{
    return [[RZDataManagerModelObjectMapping alloc] initWithModelClass:NSClassFromString(className)];
}

- (void)importData:(NSDictionary *)data toObject:(NSObject<RZDataManagerModelObject>*)object usingMapping:(RZDataManagerModelObjectMapping *)mapping
{
    if ([object respondsToSelector:@selector(prepareForImportFromData:)]){
        [object prepareForImportFromData:data];
    }
    
    for (NSString* key in [data allKeys]){
                        
        // If we have valid mapping, go ahead and import it
        id value = [data validObjectForKeyPath:key decodeHTML:NO];
        [self importValue:value toObject:object fromKeyPath:key withMapping:mapping];
        
//        // If value is a dictionary and there's no key mapping, attempt to flatten and look for keypath mappings
//        else if (mappingInfo == nil && ![keysToIgnore containsObject:key] && [[data objectForKey:key] isKindOfClass:[NSDictionary class]]){
//            
//            NSDictionary *subDict = [data objectForKey:key];
//            for (NSString *subKey in [subDict allKeys]){
//                
//                NSString *keyPath = [NSString stringWithFormat:@"%@.%@",key,subKey];
//                mappingInfo = [keyMappings objectForKey:keyPath];
//                
//                if (mappingInfo != nil){
//                    id value = [data validObjectForKeyPath:keyPath decodeHTML:NO];
//                    [self importValue:value toObject:object fromKey:keyPath withKeyMapping:mappingInfo];
//                }
//                else if (![keysToIgnore containsObject:keyPath]){
//                    NSLog(@"RZDataImporter: Could not find mapping for key path %@ in object of class %@", keyPath, NSStringFromClass([object class]));
//                }
//                
//            }
//            
//        }
//        else if (![keysToIgnore containsObject:key]){
//            NSLog(@"RZDataImporter: Could not find mapping for key %@ in object of class %@", key, NSStringFromClass([object class]));
//        }
        
    }
    
    if ([object respondsToSelector:@selector(finalizeImportFromData:)]){
        [object finalizeImportFromData:data];
    }
}

- (void)importValue:(id)value toObject:(NSObject<RZDataManagerModelObject>*)object fromKeyPath:(NSString *)keyPath withMapping:(RZDataManagerModelObjectMapping *)mapping
{
    
    // If value is string and we decode HTML, do it now
    if ([value isKindOfClass:[NSString class]]){

        // TODO: check mapping

        BOOL decodesHTML = self.shouldDecodeHTML;
        
        if (decodesHTML){
            value = [value stringByDecodingHTMLEntities];
        }
    }
    
    // Check for custom selector or relationship to handle import
    RZDataManagerModelObjectRelationshipMapping *relationshipMapping = [mapping relationshipMappingForDataKey:keyPath];
    NSString *selectorName = [mapping importSelectorNameForDataKey:keyPath];
    
    if (nil != relationshipMapping){
        
        RZDataManagerModelObjectMapping *relatedObjectMapping = [self mappingForClassNamed:relationshipMapping.relationshipObjectType];
        
        if (relatedObjectMapping != nil){
            
            NSString *relationshipIDKey = relatedObjectMapping.dataIdKey;
            NSString *relationshipModelIDKey = relatedObjectMapping.modelIdPropertyName;
            
            if (relationshipIDKey && relationshipModelIDKey){
                
                if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]])
                {
                    id relData = value;
                    
                    if ([value isKindOfClass:[NSArray class]]){
                        
                        // if array does not contain dictionaries, assume each value is a unique id value, wrap in dictionary
                        if (![[(NSArray*)value objectAtIndex:0] isKindOfClass:[NSDictionary class]])
                        {
                            NSMutableArray *dataKeyPairs = [NSMutableArray arrayWithCapacity:[(NSArray*)value count]];
                            
                            [(NSArray*)value enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                [dataKeyPairs addObject:@{relationshipIDKey : obj}];
                            }];
                            
                            relData = dataKeyPairs;
                        }
                        
                    }
                    
                    [self.dataManager importData:relData
                                      objectType:relationshipMapping.relationshipObjectType
                                 forRelationship:keyPath
                                        onObject:object
                                         options:nil
                                      completion:nil];
                }
                else{
                    // wrap in a dictionary - we will assume it's the unique identifier
                    // this is for cases when the relationship is specified by one key-value pair instead of fully-qualified
                    // data for the other object
                    
                    NSDictionary *relData = @{relationshipIDKey : value};
                    
                    [self.dataManager importData:relData
                                      objectType:relationshipMapping.relationshipObjectType
                                 forRelationship:keyPath
                                        onObject:object
                                         options:nil
                                      completion:nil];
                }
            }
            else{
                NSLog(@"Missing relationship id key and/or model id key for relationship object type %@", relationshipMapping.relationshipObjectType);
            }
        }
        else{
            NSLog(@"RZDataImporter: could not find mapping for relationship object type %@ from object type %@", relationshipMapping.relationshipObjectType, NSStringFromClass([object class]));
        }
    }
    else if (selectorName != nil){
        
        SEL importSelector = NSSelectorFromString(selectorName);
        
        if ([object respondsToSelector:importSelector]){
            
            NSMethodSignature *selectorSig = [object methodSignatureForSelector:importSelector];
            if (selectorSig.numberOfArguments > 2){
                
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:selectorSig];
                [invocation setSelector:importSelector];
                [invocation setTarget:object];
                [invocation setArgument:&value atIndex:2];
                if (selectorSig.numberOfArguments > 3){
                    id keyArg = keyPath;
                    [invocation setArgument:&keyArg atIndex:3];
                }
                
                @try {
                    [invocation invoke];
                }
                @catch (NSException *exception) {
                    NSLog(@"RZDataImporter: Error invoking setter %@ on object of class %@: %@", NSStringFromSelector(importSelector), NSStringFromClass([object class]), exception);
                }
                
            }
            else{
                NSLog(@"RZDataImporter: Too few arguments for import selector %@ on object of class %@", selectorName, NSStringFromClass([object class]));
            }
        }
        else{
            NSLog(@"RZDataImporter: Unable to perform custom import selector %@ on object of class %@", selectorName, NSStringFromClass([object class]));
        }
        
    }
    else
    {
        // import as a property
        [self setPropertyValue:value onObject:object fromKeyPath:keyPath withMapping:mapping];
    }
}

- (void)setPropertyValue:(id)value onObject:(NSObject<RZDataManagerModelObject> *)object fromKeyPath:(NSString *)keyPath withMapping:(RZDataManagerModelObjectMapping *)mapping
{
    // otherwise, at bare minimum we need an object key
    // if it's not overridden, just use the data key
    NSString *propertyName = [mapping modelPropertyNameForDataKey:keyPath];
    
    SEL setter = [self setterFromPropertyName:propertyName];
    if ([object respondsToSelector:setter]){
        
        // NSInvocation allows passing scalars to setter
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:setter]];
        [invocation setSelector:setter];
        [invocation setTarget:object];
        
        // Check for explicit conversion
        NSString *conversion = [[object class] dataTypeForPropertyNamed:propertyName];
        
        // Perform scalar conversions - need to set invocation argument separately since
        // we can't assign a scalar value to id
        
        BOOL isNSValue = [value isKindOfClass:[NSValue class]];
        
        if (isNSValue && [conversion isEqualToString:kRZDataManagerTypeChar]){
            char charValue = [value charValue];
            [invocation setArgument:&charValue atIndex:2];
        }
        else if (isNSValue && [conversion isEqualToString:kRZDataManagerTypeInt]){
            NSInteger intValue = [value integerValue];
            [invocation setArgument:&intValue atIndex:2];
        }
        else if (isNSValue && [conversion isEqualToString:kRZDataManagerTypeUnsignedInt]){
            NSUInteger uIntValue = [value unsignedIntegerValue];
            [invocation setArgument:&uIntValue atIndex:2];
        }
        else if (isNSValue && [conversion isEqualToString:kRZDataManagerTypeFloat]){
            float floatValue = [value floatValue];
            [invocation setArgument:&floatValue atIndex:2];
        }
        else if (isNSValue && [conversion isEqualToString:kRZDataManagerTypeDouble]){
            double doubleValue = [value doubleValue];
            [invocation setArgument:&doubleValue atIndex:2];
        }
        else {
            
            // perform NSObject type conversion
            if (conversion != nil && value != nil){
                
                // TODO: Format overrides
                NSString *format = mapping.dateFormat;
                value = [self convertValue:value toType:conversion withFormat:format];
            }
            
            // set invocation argument from value
            [invocation setArgument:&value atIndex:2];
        }
        
        @try {
            [invocation invoke];
        }
        @catch (NSException *exception) {
            NSLog(@"RZDataImporter: Error invoking setter %@ on object of class %@: %@", NSStringFromSelector(setter), NSStringFromClass([object class]), exception);
        }
        
    }
    else{
        NSLog(@"RZDataImporter: Object does not repsond to setter %@", NSStringFromSelector(setter));
    }

}

- (id)convertValue:(id)value toType:(NSString *)conversionType withFormat:(NSString *)format
{
    id newValue = value;
    
    if ([conversionType isEqualToString:kRZDataManagerTypeNSDate])
    {
        if ([value isKindOfClass:[NSString class]]){
            
            @synchronized(self.dateFormatter){
                if (format){
                    [self.dateFormatter setLocale:[NSLocale currentLocale]];
                    [self.dateFormatter setDateFormat:format];
                }
                else{
                    [self.dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
                    [self.dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
                    [self.dateFormatter setDateFormat:self.defaultDateFormat];
                }
                
                newValue = [self.dateFormatter dateFromString:(NSString*)value];
            }
        }
        else if ([value isKindOfClass:[NSNumber class]]){
            
            // Assuming it's seconds since epoch
            newValue = [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)value doubleValue]];
        }
        else if (![value isKindOfClass:[NSDate class]]){
            NSLog(@"RZDataImporter: Object of class %@ cannot be converted to NSDate", NSStringFromClass([value class]));
        }
    }
    else if ([conversionType isEqualToString:kRZDataManagerTypeNSNumber])
    {
        if ([value isKindOfClass:[NSString class]]){
            @synchronized(self.numberFormatter){
                newValue = [self.numberFormatter numberFromString:(NSString*)value];
            }
        }
        else if (![value isKindOfClass:[NSNumber class]]){
            NSLog(@"RZDataImporter: Object of class %@ cannot be converted to NSNumber", NSStringFromClass([value class]));
        }
    }
    else if ([conversionType isEqualToString:kRZDataManagerTypeNSString])
    {
        if ([value respondsToSelector:@selector(stringValue)])
        {
            newValue = [value stringValue];
        }
        else if (![value isKindOfClass:[NSString class]])
        {
            newValue = [NSString stringWithFormat:@"%@", value];
        }
    }
    
    return newValue;
}

- (SEL)setterFromPropertyName:(NSString *)propertyName
{
    // capitalize the first letter of the key
    NSMutableString *mutablePropName = [propertyName mutableCopy];
    [mutablePropName replaceCharactersInRange:NSMakeRange(0, 1) withString:[[mutablePropName substringWithRange:NSMakeRange(0, 1)] capitalizedString]];
    
    NSString *setterString = [NSString stringWithFormat:@"set%@:", mutablePropName];
    
    return NSSelectorFromString(setterString);
}

@end

@implementation RZDataImporterDiffInfo

- (id)init{
    self = [super init];
    if (self){
        self.insertedObjectIndices = [NSMutableArray arrayWithCapacity:16];
        self.removedObjectIndices = [NSMutableArray arrayWithCapacity:16];
        self.movedObjectIndices = [NSMutableArray arrayWithCapacity:16];
    }
    return self;
}

@end
