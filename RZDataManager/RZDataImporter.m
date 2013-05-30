//
//  RZDataImporter.m
//
//  Created by Nick Donaldson on 2/26/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataImporter.h"
#import "RZDataManager.h"
#import "NSDictionary+NonNSNull.h"
#import "NSString+HTMLEntities.h"
#import "NSObject+PropertyTypes.h"

static NSString* const kRZDataImporterDateFormat = @"Date Format";
static NSString* const kRZDataImporterDefaultIDKey = @"Default ID Key";
static NSString* const kRZDataImporterDataKeys = @"Data Keys";
static NSString* const kRZDataImporterIgnoreKeys = @"Ignore Keys";
static NSString* const kRZDataImporterObjectKey = @"Object Key";
static NSString* const kRZDataImporterConversion = @"Conversion";
static NSString* const kRZDataImporterRelationship = @"Relationship";
static NSString* const kRZDataImporterRelationshipIDKey = @"Relationship ID Key";
static NSString* const kRZDataImporterFormat = @"Format";
static NSString* const kRZDataImporterSelector = @"Selector";
static NSString* const kRZDataImporterDecodeHTML = @"Decode HTML";

static NSString* const kRZDataImporterConversionTypeString = @"NSString";
static NSString* const kRZDataImporterConversionTypeDate = @"NSDate";
static NSString* const kRZDataImporterConversionTypeNumber = @"NSNumber";
static NSString* const kRZDataImporterConversionTypeInt = @"NSInteger";
static NSString* const kRZDataImporterConversionTypeUnsignedInt = @"NSUInteger";
static NSString* const kRZDataImporterConversionTypeFloat = @"float";
static NSString* const kRZDataImporterConversionTypeDouble = @"double";
static NSString* const kRZDataImporterConversionTypeBool = @"BOOL";

static NSString* const kRZDataImporterISODateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'";

@interface RZDataImporter ()

@property (nonatomic, strong) NSMutableDictionary *modelMappings;
@property (nonatomic, strong) NSMutableDictionary *defaultDataIdKeys;
@property (nonatomic, strong) NSMutableDictionary *defaultModelIdKeys;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSNumberFormatter *numberFormatter;
@property (nonatomic, strong) NSString *objectDateFormat;

- (void)importData:(NSDictionary *)data toObject:(NSObject<RZDataImporterModelObject>*)object withMapping:(NSDictionary*)mapping;

- (void)importValue:(id)value toObject:(NSObject<RZDataImporterModelObject>*)object fromKey:(NSString*)key withKeyMapping:(NSDictionary*)mappingInfo;

- (void)setPropertyValue:(id)value onObject:(NSObject<RZDataImporterModelObject>*)object fromKey:(NSString*)key withKeyMapping:(NSDictionary*)mappingInfo;

- (SEL)setterFromObjectKey:(NSString*)key;

- (id)convertValue:(id)value toType:(NSString*)conversionType withFormat:(NSString*)format;

@end

@implementation RZDataImporter

- (id)init
{
    self = [super init];
    if (self){
        
        self.shouldDecodeHTML = NO;
        
        self.modelMappings = [NSMutableDictionary dictionaryWithCapacity:16];
        self.defaultDataIdKeys = [NSMutableDictionary dictionaryWithCapacity:16];
        self.defaultModelIdKeys = [NSMutableDictionary dictionaryWithCapacity:16];
        
        self.dateFormatter = [[NSDateFormatter alloc] init];
        self.numberFormatter = [[NSNumberFormatter alloc] init];
        self.numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    }
    return self;
}

#pragma mark - Public

- (NSDictionary*)mappingForObjectType:(NSString *)objectTypeName
{
    // First, check cache
    NSDictionary *mapping = [self.modelMappings objectForKey:objectTypeName];
    
    // Second, check bundle
    if (mapping == nil){
        
        NSString *plistName = [objectTypeName stringByAppendingString:@"Mapping"];
        NSURL *plistUrl = [[NSBundle mainBundle] URLForResource:plistName withExtension:@"plist"];
        
        if (plistUrl != nil){
            mapping = [[NSDictionary alloc] initWithContentsOfURL:plistUrl];
        }
    }
    
    // TODO: Third, fallback to an inferred mapping.
        
    if (mapping != nil){
        [self.modelMappings setObject:mapping forKey:objectTypeName];
    }
    
    return mapping;
}

- (void)setMapping:(NSDictionary *)mapping forObjectType:(NSString *)objectTypeName
{
    if (mapping && objectTypeName){
        [self.modelMappings setObject:mapping forKey:objectTypeName];
    }
}

- (void)getDefaultIdKeysForObjectType:(NSString*)objectTypeName
                            dataIdKey:(NSString*__autoreleasing *)dataIdKey
                           modelIdKey:(NSString*__autoreleasing *)modelIdKey;
{

    NSString *defaultDataIdKey = [self.defaultDataIdKeys objectForKey:objectTypeName];
    NSString *defaultModelIdKey = [self.defaultModelIdKeys objectForKey:objectTypeName];
    
    if (defaultDataIdKey && defaultModelIdKey){
        
        
    }
    else{
    
        NSDictionary *mapping = [self mappingForObjectType:objectTypeName];
        if (mapping){
            
            defaultDataIdKey = [mapping objectForKey:kRZDataImporterDefaultIDKey];
            if (defaultDataIdKey){
                
                NSDictionary *dataKeys = [mapping objectForKey:kRZDataImporterDataKeys];
                if ([[dataKeys allKeys] containsObject:defaultDataIdKey]){
                    
                    NSDictionary *defaultKeyMapping = [dataKeys objectForKey:defaultDataIdKey];
                    defaultModelIdKey = [defaultKeyMapping objectForKey:kRZDataImporterObjectKey];
                    if (defaultModelIdKey == nil) defaultModelIdKey = defaultDataIdKey;
                    
                    // cache 'em
                    [self.defaultDataIdKeys setObject:defaultDataIdKey forKey:objectTypeName];
                    [self.defaultModelIdKeys setObject:defaultModelIdKey forKey:objectTypeName];
                
                }            
            }
        }
    }
    
    if (dataIdKey){
        *dataIdKey = defaultDataIdKey;
    }
    
    if (modelIdKey){
        *modelIdKey = defaultModelIdKey;
    }
}

- (void)importData:(NSDictionary *)data toObject:(NSObject<RZDataImporterModelObject> *)object
{
    [self importData:data toObject:object ofType:NSStringFromClass([object class])];
}

- (void)importData:(NSDictionary *)data toObject:(NSObject<RZDataImporterModelObject>*)object ofType:(NSString *)objTypeName
{
    // TODO: Maybe raise exception here
    if (object && data){
        
        NSDictionary *mapping = [self mappingForObjectType:objTypeName];
        if (mapping != nil){
            
            if ([object respondsToSelector:@selector(prepareForImportFromData:)]){
                [object prepareForImportFromData:data];
            }
            
            [self importData:data toObject:object withMapping:mapping];
            
            if ([object respondsToSelector:@selector(finalizeImportFromData:)]){
                [object finalizeImportFromData:data];
            }
            
        }
        else{
            NSLog(@"RZDataImporter: Could not find mapping for class %@", NSStringFromClass([object class]));
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

- (void)importData:(NSDictionary *)data toObject:(NSObject<RZDataImporterModelObject>*)object withMapping:(NSDictionary *)mapping
{
    NSDictionary *keyMappings = [mapping objectForKey:kRZDataImporterDataKeys];
    
    NSArray *keysToIgnore = [mapping objectForKey:kRZDataImporterIgnoreKeys];
   
    self.objectDateFormat = [mapping objectForKey:kRZDataImporterDateFormat];
        
    for (NSString* key in [data allKeys]){
                
        NSDictionary *mappingInfo = [keyMappings objectForKey:key];
        
        // If we have valid mapping, go ahead and import it
        if (mappingInfo != nil){
            
            id value = [data validObjectForKeyPath:key decodeHTML:NO];
            
            [self importValue:value toObject:object fromKey:key withKeyMapping:mappingInfo];
            
        }
        // If value is a dictionary and there's no key mapping, attempt to flatten and look for keypath mappings
        else if (mappingInfo == nil && ![keysToIgnore containsObject:key] && [[data objectForKey:key] isKindOfClass:[NSDictionary class]]){
            
            NSDictionary *subDict = [data objectForKey:key];
            for (NSString *subKey in [subDict allKeys]){
                
                NSString *keyPath = [NSString stringWithFormat:@"%@.%@",key,subKey];
                mappingInfo = [keyMappings objectForKey:keyPath];
                
                if (mappingInfo != nil){
                    id value = [data validObjectForKeyPath:keyPath decodeHTML:NO];
                    [self importValue:value toObject:object fromKey:keyPath withKeyMapping:mappingInfo];
                }
                else if (![keysToIgnore containsObject:keyPath]){
                    NSLog(@"RZDataImporter: Could not find mapping for key path %@ in object of class %@", keyPath, NSStringFromClass([object class]));
                }
                
            }
            
        }
        else if (![keysToIgnore containsObject:key]){
            NSLog(@"RZDataImporter: Could not find mapping for key %@ in object of class %@", key, NSStringFromClass([object class]));
        }
        
    }
    
}

- (void)importValue:(id)value toObject:(NSObject<RZDataImporterModelObject>*)object fromKey:key withKeyMapping:(NSDictionary *)mappingInfo
{
    
    // If value is string and we decode HTML, do it now
    if ([value isKindOfClass:[NSString class]]){
    
        BOOL decodesHTML = self.shouldDecodeHTML;
        
        NSString *decodeHTMLString = [mappingInfo objectForKey:kRZDataImporterDecodeHTML];
        if (decodeHTMLString != nil){
            decodesHTML = [[[mappingInfo objectForKey:kRZDataImporterDecodeHTML] lowercaseString] isEqualToString:@"yes"];
        }
        
        if (decodesHTML){
            value = [value stringByDecodingHTMLEntities];
        }
    }
    
    // Check for custom selector or relationship to handle import
    NSString *relationshipObjType = [mappingInfo objectForKey:kRZDataImporterRelationship];
    NSString *selectorName = [mappingInfo objectForKey:kRZDataImporterSelector];
    
    if (relationshipObjType != nil){
        
        NSDictionary *relMapping = [self mappingForObjectType:relationshipObjType];
        
        if (relMapping != nil){
            
            NSString *relationshipModelIDKey = nil;
            NSString *relationshipIDKey = [mappingInfo objectForKey:kRZDataImporterRelationshipIDKey];
            
            if (relationshipIDKey){
                
                // find the model key mapping for the identifier key
                NSDictionary *relDataKeys = [relMapping objectForKey:kRZDataImporterDataKeys];
                NSDictionary *relKeyMapping = [relDataKeys objectForKey:relationshipIDKey];
                if (relKeyMapping){
                    relationshipModelIDKey = [relKeyMapping objectForKey:kRZDataImporterObjectKey];
                    if (relationshipModelIDKey == nil){
                        relationshipModelIDKey = relationshipIDKey;
                    }
                }
            }
            
            if (relationshipIDKey && relationshipModelIDKey){
                
                if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]])
                {
                    id importData = value;
                    
                    if ([value isKindOfClass:[NSArray class]]){
                        
                        // if array does not contain dictionaries, assume each value is a unique id value, wrap in dictionary
                        if (![[(NSArray*)value objectAtIndex:0] isKindOfClass:[NSDictionary class]])
                        {
                            NSMutableArray *dataKeyPairs = [NSMutableArray arrayWithCapacity:[(NSArray*)value count]];
                            
                            [(NSArray*)value enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                [dataKeyPairs addObject:@{relationshipIDKey : obj}];
                            }];
                            
                            importData = dataKeyPairs;
                        }
                        
                    }
                    [self.dataManager importData:importData
                                      objectType:relationshipObjType
                                   dataIdKeyPath:relationshipIDKey
                                  modelIdKeyPath:relationshipModelIDKey
                                 forRelationship:key
                                        onObject:object
                                      completion:nil];
                }
                else{
                    // wrap in a dictionary - we will assume it's the unique identifier
                    // this is for cases when the relationship is specified by one key-value pair instead of fully-qualified
                    // data for the other object
                    NSDictionary *importData = @{relationshipIDKey : value};
                    [self.dataManager importData:importData
                                      objectType:relationshipObjType
                                   dataIdKeyPath:relationshipIDKey
                                  modelIdKeyPath:relationshipModelIDKey
                                 forRelationship:key
                                        onObject:object
                                      completion:nil];
                }
            }
            else{
                NSLog(@"Missing relationship id key and/or model id key for relationship object type %@", relationshipObjType);
            }
        }
        else{
            NSLog(@"RZDataImporter: could not find mapping for relationship object type %@ from object type %@", relationshipObjType, NSStringFromClass([object class]));
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
                    id keyArg = key;
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
    else{
        // import as a property
        [self setPropertyValue:value onObject:object fromKey:key withKeyMapping:mappingInfo];
    }
}

- (void)setPropertyValue:(id)value onObject:(NSObject<RZDataImporterModelObject> *)object fromKey:(NSString *)key withKeyMapping:(NSDictionary *)mappingInfo
{
    // otherwise, at bare minimum we need an object key
    // if it's not overridden, just use the data key
    NSString *objectKey = [mappingInfo objectForKey:kRZDataImporterObjectKey];
    if (objectKey == nil){
        objectKey = key;
    }
    
    SEL setter = [self setterFromObjectKey:objectKey];
    if ([object respondsToSelector:setter]){
        
        // NSInvocation allows passing scalars to setter
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:setter]];
        [invocation setSelector:setter];
        [invocation setTarget:object];
        
        // Check for explicit conversion
        NSString *conversion = [mappingInfo objectForKey:kRZDataImporterConversion];
        
        // if no explicit conversion, infer from property type
        if (conversion == nil){
            conversion = [object typeNameForProperty:objectKey];
        }
        
        // Perform scalar conversions - need to set invocation argument separately since
        // we can't assign a scalar value to id
        if ([conversion isEqualToString:kRZDataImporterConversionTypeBool] && [value isKindOfClass:[NSValue class]]){
            BOOL boolValue = [value boolValue];
            [invocation setArgument:&boolValue atIndex:2];
        }
        else if ([conversion isEqualToString:kRZDataImporterConversionTypeInt] && [value isKindOfClass:[NSValue class]]){
            NSInteger intValue = [value integerValue];
            [invocation setArgument:&intValue atIndex:2];
        }
        else if ([conversion isEqualToString:kRZDataImporterConversionTypeUnsignedInt] && [value isKindOfClass:[NSValue class]]){
            NSUInteger uIntValue = [value unsignedIntegerValue];
            [invocation setArgument:&uIntValue atIndex:2];
        }
        else if ([conversion isEqualToString:kRZDataImporterConversionTypeFloat] && [value isKindOfClass:[NSValue class]]){
            float floatValue = [value floatValue];
            [invocation setArgument:&floatValue atIndex:2];
        }
        else if ([conversion isEqualToString:kRZDataImporterConversionTypeDouble] && [value isKindOfClass:[NSValue class]]){
            double doubleValue = [value doubleValue];
            [invocation setArgument:&doubleValue atIndex:2];
        }
        else {
            
            // perform NSObject type conversion
            if (conversion != nil && value != nil){
                
                NSString *format = [mappingInfo objectForKey:kRZDataImporterFormat];
                if (format == nil){
                    // fall back to default for this mapping
                    format = self.objectDateFormat;
                }
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
    
    if ([conversionType isEqualToString:kRZDataImporterConversionTypeDate])
    {
        if ([value isKindOfClass:[NSString class]]){
            
            @synchronized(self.dateFormatter){
                if (format){
                    [self.dateFormatter setLocale:[NSLocale currentLocale]];
                    [self.dateFormatter setDateFormat:format];
                }
                else{
                    [self.dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
                    [self.dateFormatter setDateFormat:kRZDataImporterISODateFormat];
                    [self.dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
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
    else if ([conversionType isEqualToString:kRZDataImporterConversionTypeNumber])
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
    else if ([conversionType isEqualToString:kRZDataImporterConversionTypeString])
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

- (SEL)setterFromObjectKey:(NSString *)key
{
    // capitalize the first letter of the key
    NSMutableString *mutableKey = [key mutableCopy];
    [mutableKey replaceCharactersInRange:NSMakeRange(0, 1) withString:[[mutableKey substringWithRange:NSMakeRange(0, 1)] capitalizedString]];
    
    NSString *setterString = [NSString stringWithFormat:@"set%@:", mutableKey];
    
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
