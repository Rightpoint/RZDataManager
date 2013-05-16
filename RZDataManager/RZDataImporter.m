//
//  RZDataImporter.m
//
//  Created by Nick Donaldson on 2/26/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataImporter.h"
#import "NSDictionary+NonNSNull.h"
#import "NSString+HTMLEntities.h"

static NSString* const kRZDataImporterDateFormat = @"Date Format";
static NSString* const kRZDataImporterDataKeys = @"Data Keys";
static NSString* const kRZDataImporterIgnoreKeys = @"Ignore Keys";
static NSString* const kRZDataImporterObjectKey = @"Object Key";
static NSString* const kRZDataImporterConversion = @"Conversion";
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

static NSString* const kRZDataImporterISODateFormat = @"yyyy-MM-dd`T`hh:mm:ss'Z'";

@interface RZDataImporter ()

@property (nonatomic, strong) NSCache *modelMappings;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSNumberFormatter *numberFormatter;
@property (nonatomic, strong) NSString *objectDateFormat;

- (id)initInternal;

- (NSDictionary*)mappingForClass:(Class)objClass;

- (void)importData:(NSDictionary *)data toObject:(NSObject<RZDataImporterModelObject>*)object withMapping:(NSDictionary*)mapping;

- (void)importValue:(id)value toObject:(NSObject<RZDataImporterModelObject>*)object fromKey:(NSString*)key withKeyMapping:(NSDictionary*)mappingInfo;

- (SEL)setterFromObjectKey:(NSString*)key;

- (id)convertValue:(id)value toType:(NSString*)conversionType withFormat:(NSString*)format;

@end

@implementation RZDataImporter

+ (RZDataImporter*)sharedImporter
{
    static RZDataImporter *sharedImporter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedImporter = [[RZDataImporter alloc] initInternal];
    });
    return sharedImporter;
}

- (id)init{
    [NSException raise:NSInternalInconsistencyException format:@"-init is not a valid initializer for singleton RZDataImporter. Use +sharedImporter"];
    return nil;
}

- (id)initInternal
{
    self = [super init];
    if (self){
        self.shouldDecodeHTML = YES;
        self.modelMappings = [[NSCache alloc] init];
        self.dateFormatter = [[NSDateFormatter alloc] init];
        self.numberFormatter = [[NSNumberFormatter alloc] init];
        self.numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    }
    return self;
}

#pragma mark - Public

- (void)importData:(NSDictionary *)data toObject:(NSObject<RZDataImporterModelObject>*)object
{
    // TODO: Maybe raise exception here
    if (object && data){
        
        NSDictionary *mapping = [self mappingForClass:[object class]];
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


- (RZDataImporterDiffInfo*)updateObjects:(NSArray*)objects
                                 ofClass:(Class)objClass
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
                    __block id item = nil;
                    id uniqueValue = nil;
                    NSArray* matchingItems = nil;
                    
                    // try to find matching object
                    if (dataIdKeyPath != nil && modelIdKeyPath != nil){
                        
                        uniqueValue = [dataDict validObjectForKeyPath:dataIdKeyPath decodeHTML:self.shouldDecodeHTML];
                        if (uniqueValue != nil){
                            
                            // find existing item
                            NSPredicate *matchPred = [NSPredicate predicateWithFormat:@"%K == %@", modelIdKeyPath, uniqueValue];
                            matchingItems = [objects filteredArrayUsingPredicate:matchPred];
                            if (matchingItems.count > 0){
                                item = [matchingItems objectAtIndex:0];
                            }
                        }
                    }
                    
                    // create new object if necessary
                    if (item == nil){
                        
                        // see if it implements RZDataImporterModelObject, and try to get cached instance
                        if (uniqueValue != nil && [objClass instancesRespondToSelector:@selector(cachedObjectWithUniqueValue:forKey:)]){
                            item = [objClass cachedObjectWithUniqueValue:uniqueValue forKeyPath:modelIdKeyPath];
                        }
                        
                        // if still nil, allocate new one
                        if (item == nil){
                            item = [[objClass alloc] init];
                        }
                        
                        [diffInfo.addedObjects addObject:item];
                        [diffInfo.insertionIndices addObject:[NSNumber numberWithInteger:idx]];
                    }
                    else if (matchingItems.count == 1){
                        
                        [diffInfo.movedObjects addObject:item];
                        [diffInfo.moveIndices addObject:[NSNumber numberWithInteger:idx]];
                    }
                    
                    // set item data
                    if (item != nil){
                        [self importData:dataDict toObject:item];
                    }                

                }
            }];

        }
        
        // Enumerate items that aren't in array
        NSArray *currentUniqueVals = [dataDicts valueForKeyPath:dataIdKeyPath];
        [objects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:objClass]){
                id objValue = [obj valueForKeyPath:modelIdKeyPath];
                if (![currentUniqueVals containsObject:objValue]){
                    [diffInfo.removedObjects addObject:obj];
                }
            }
        }];
    }
    
    return diffInfo;
}


#pragma mark - Private

- (NSDictionary*)mappingForClass:(Class)objClass
{
    NSString *className = NSStringFromClass(objClass);
    
    // First check cache
    NSDictionary *mapping = [self.modelMappings objectForKey:className];
    
    // Second check bundle
    if (mapping == nil){
        
        NSString *plistName = [className stringByAppendingString:@"Mapping"];
        NSURL *plistUrl = [[NSBundle mainBundle] URLForResource:plistName withExtension:@"plist"];
        
        if (plistUrl != nil){
            mapping = [[NSDictionary alloc] initWithContentsOfURL:plistUrl];
        }
    }
    
    // TODO: Third, check a private, non-temporary disk location for automatically created maps
    
    // TODO: Fourth, fall back to automatically creating mapping as best as possible, save to private disk location
    
    if (mapping != nil){
        [self.modelMappings setObject:mapping forKey:className];
    }
    
    return mapping;
}

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
    
    // Check for custom selector to handle import
    NSString *selectorName = [mappingInfo objectForKey:kRZDataImporterSelector];
    
    if (selectorName != nil){
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
            
            // Check for conversion
            NSString *conversion = [mappingInfo objectForKey:kRZDataImporterConversion];
            
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
}

- (id)convertValue:(id)value toType:(NSString *)conversionType withFormat:(NSString *)format
{
    id newValue = value;
    
    if ([conversionType isEqualToString:kRZDataImporterConversionTypeDate])
    {
        if ([value isKindOfClass:[NSString class]]){
            
            if (format){
                [self.dateFormatter setDateFormat:format];
            }
            else{
                [self.dateFormatter setDateFormat:kRZDataImporterISODateFormat];
            }
            
            newValue = [self.dateFormatter dateFromString:(NSString*)value];
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
            
            newValue = [self.numberFormatter numberFromString:(NSString*)value];
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
        else
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
        
        self.addedObjects = [NSMutableArray arrayWithCapacity:16];
        self.insertionIndices = [NSMutableArray arrayWithCapacity:16];
        self.removedObjects = [NSMutableArray arrayWithCapacity:16];
        self.movedObjects = [NSMutableArray arrayWithCapacity:16];
        self.moveIndices = [NSMutableArray arrayWithCapacity:16];
    }
    return self;
}

@end
