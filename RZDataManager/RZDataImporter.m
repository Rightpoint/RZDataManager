//
//  RZDataImporter.m
//
//  Created by Nick Donaldson on 2/26/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZDataImporter.h"
#import "RZDataManager_Base.h"

#import "RZDataManagerModelObjectMapping.h"

#import "NSDictionary+NonNSNull.h"
#import "NSString+HTMLEntities.h"
#import "NSObject+RZPropertyUtils.h"
#import "RZLogHelper.h"

@interface RZDataImporter ()

@property (nonatomic, strong) NSMutableDictionary *modelMappings;

@property (nonatomic, strong) NSDateFormatter   *dateFormatter;
@property (nonatomic, strong) NSNumberFormatter *numberFormatter;

- (RZDataManagerModelObjectMapping *)createMappingForClassNamed:(NSString *)className;

- (void)importValue:(id)value
           toObject:(NSObject <RZDataManagerModelObject> *)object
        fromKeyPath:(NSString *)keyPath
        withMapping:(RZDataManagerModelObjectMapping *)mapping;

- (void)setPropertyValue:(id)value
                onObject:(NSObject <RZDataManagerModelObject> *)object
             fromKeyPath:(NSString *)keyPath
             withMapping:(RZDataManagerModelObjectMapping *)mapping;

- (SEL)setterFromPropertyName:(NSString *)propertyName;

- (id)convertValue:(id)value toType:(NSString *)conversionType withFormat:(NSString *)format;

- (void)logErrorMessage:(NSString *)errorMessage, ...;

@end

@implementation RZDataImporter

- (id)init
{
    self = [super init];
    if (self)
    {

        self.shouldDecodeHTML = NO;

        self.modelMappings = [NSMutableDictionary dictionaryWithCapacity:16];

        // Assume all dates are UTC
        self.dateFormatter               = [[NSDateFormatter alloc] init];
        [self.dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [self.dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        
        self.numberFormatter             = [[NSNumberFormatter alloc] init];
        self.numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        self.defaultDateFormat           = kRZDataManagerUTCDateFormat;
    }
    return self;
}

- (void)logErrorMessage:(NSString *)errorMessage, ...
{

}

#pragma mark - Public

- (RZDataManagerModelObjectMapping *)mappingForClassNamed:(NSString *)className
{
    RZDataManagerModelObjectMapping *mapping = nil;

    if (nil != className)
    {
        // First, check cache
        mapping = [self.modelMappings objectForKey:className];

        // If not in cache, build mapping from object class
        if (mapping == nil)
        {
            mapping = [self createMappingForClassNamed:className];
        }

        if (mapping != nil)
        {
            [self.modelMappings setObject:mapping forKey:className];
        }
    }

    return mapping;
}


- (void)importData:(NSDictionary *)data toObject:(NSObject <RZDataManagerModelObject> *)object
{
    // TODO: Maybe raise exception here
    if (object && data)
    {

        NSString *className = NSStringFromClass([object class]);

        if ([object conformsToProtocol:@protocol(RZDataManagerModelObject)])
        {
            RZDataManagerModelObjectMapping *mapping = [self mappingForClassNamed:className];
            if (mapping != nil)
            {
                [self importData:data toObject:object usingMapping:mapping];
            }
        }
        else
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:[NSString stringWithFormat:@"Class %@ does not conform to RZDataManagerModelObject protocol", className]
                                         userInfo:nil];
        }

    }
}

// TODO: Reimplement this for no-plist configuration

//
//- (RZDataImporterDiffInfo*)diffInfoForObjects:(NSArray*)objects
//                                     withData:(id)data
//                                dataIdKeyPath:(NSString*)dataIdKeyPath
//                               modelIdKeyPath:(NSString*)modelIdKeyPath
//{
//    
//    RZDataImporterDiffInfo *diffInfo = [[RZDataImporterDiffInfo alloc] init];
//    
//    NSArray *dataDicts = nil;
//    if ([data isKindOfClass:[NSArray class]]){
//        dataDicts = data;
//    }
//    else if ([data isKindOfClass:[NSDictionary class]]){
//        dataDicts = @[data];
//    }
//    
//    if (dataDicts != nil){
//        
//        // Update and insert new items
//        if (dataDicts.count > 0){
//            
//            [dataDicts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//                if ([obj isKindOfClass:[NSDictionary class]]){
//                    
//                    NSDictionary* dataDict = obj;
//                    id uniqueValue = nil;
//                    NSArray* matchingItems = nil;
//                    
//                    BOOL itemExists = NO;
//                    
//                    // try to find matching object
//                    if (dataIdKeyPath != nil && modelIdKeyPath != nil){
//                        
//                        uniqueValue = [dataDict validObjectForKeyPath:dataIdKeyPath decodeHTML:self.shouldDecodeHTML];
//                        if (uniqueValue != nil){
//                            
//                            // find existing item
//                            NSPredicate *matchPred = [NSPredicate predicateWithFormat:@"%K == %@", modelIdKeyPath, uniqueValue];
//                            matchingItems = [objects filteredArrayUsingPredicate:matchPred];
//                            itemExists = (matchingItems.count > 0);
//                        }
//                    }
//                    
//                    // create new object if necessary
//                    if (!itemExists){
//                        [diffInfo.insertedObjectIndices addObject:@(idx)];
//                    }
//                    else if (matchingItems.count == 1){
//                        [diffInfo.movedObjectIndices addObject:@(idx)];
//                    }
//                }
//            }];
//
//        }
//        
//        // Enumerate items that aren't in array
//        NSArray *currentUniqueVals = [dataDicts valueForKeyPath:dataIdKeyPath];
//        [objects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//            id objValue = [obj valueForKeyPath:modelIdKeyPath];
//            if (![currentUniqueVals containsObject:objValue]){
//                [diffInfo.removedObjectIndices addObject:@(idx)];
//            }
//        }];
//    }
//    
//    return diffInfo;
//}


#pragma mark - Private

- (RZDataManagerModelObjectMapping *)createMappingForClassNamed:(NSString *)className
{
    return [[RZDataManagerModelObjectMapping alloc] initWithModelClass:NSClassFromString(className)];
}

- (void)importData:(NSDictionary *)data
          toObject:(NSObject <RZDataManagerModelObject> *)object
      usingMapping:(RZDataManagerModelObjectMapping *)mapping
{
    // Prepare for import
    if ([object respondsToSelector:@selector(prepareForImportFromData:)])
    {
        [object prepareForImportFromData:data];
    }

    // Do the import
    for (NSString *key in [data allKeys])
    {

        if ([[mapping keysToIgnore] containsObject:key]) continue;

        id value = [data validObjectForKey:key decodeHTML:NO];

        // If we have valid mapping, go ahead and import it
        if ([mapping hasMappingDefinedForDataKey:key])
        {
            [self importValue:value toObject:object fromKeyPath:key withMapping:mapping];
        }
                // If value is a dictionary and there's no key mapping, attempt to flatten and look for keypath mappings
        else
        {
            if ([value isKindOfClass:[NSDictionary class]])
            {
                NSDictionary  *subDict = value;
                for (NSString *subKey in [subDict allKeys])
                {

                    NSString *keyPath = [NSString stringWithFormat:@"%@.%@", key, subKey];

                    if ([mapping modelPropertyNameForDataKey:keyPath] != nil)
                    {
                        id subValue = [data validObjectForKeyPath:keyPath decodeHTML:NO];
                        [self importValue:subValue toObject:object fromKeyPath:keyPath withMapping:mapping];
                    }
                    else if (![[mapping keysToIgnore] containsObject:keyPath])
                    {
                        RZLogDebug(@"Could not find mapping for key path %@ in object of class %@", keyPath, NSStringFromClass([object class]));
                    }

                }
            }
            else
            {
                RZLogDebug(@"Could not find mapping for key %@ in object of class %@", key, NSStringFromClass([object class]));
            }

        }

    }

    // Finalize the import
    if ([object respondsToSelector:@selector(finalizeImportFromData:)])
    {
        [object finalizeImportFromData:data];
    }
}

- (void)importValue:(id)value
           toObject:(NSObject <RZDataManagerModelObject> *)object
        fromKeyPath:(NSString *)keyPath
        withMapping:(RZDataManagerModelObjectMapping *)mapping
{
    // If value is string and we decode HTML, do it now
    if ([value isKindOfClass:[NSString class]])
    {
        // TODO: check mapping
        BOOL decodesHTML = self.shouldDecodeHTML;

        if (decodesHTML)
        {
            value = [value stringByDecodingHTMLEntities];
        }
    }

    // Check for custom selector or relationship to handle import
    RZDataManagerModelObjectRelationshipMapping *relationshipMapping = [mapping relationshipMappingForDataKey:keyPath];
    NSString                                    *selectorName        = [mapping importSelectorNameForDataKey:keyPath];

    if (nil != relationshipMapping)
    {

        RZDataManagerModelObjectMapping *relatedObjectMapping = [self mappingForClassNamed:relationshipMapping.relationshipClassName];

        if (relatedObjectMapping != nil)
        {

            // If value is non-nil, import related object. Otherwise use invocation to nil it out.
            if (value != nil)
            {

                NSString *relationshipIDKey      = relatedObjectMapping.dataIdKey;
                NSString *relationshipModelIDKey = relatedObjectMapping.modelIdPropertyName;

                if (relationshipIDKey && relationshipModelIDKey)
                {

                    if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]])
                    {
                        id relData = value;

                        if ([value isKindOfClass:[NSArray class]])
                        {

                            // if array does not contain dictionaries, assume each value is a unique id value, wrap in dictionary
                            if (![[(NSArray *)value objectAtIndex:0] isKindOfClass:[NSDictionary class]])
                            {
                                NSMutableArray *dataKeyPairs = [NSMutableArray arrayWithCapacity:[(NSArray *)value count]];

                                [(NSArray *)value enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
                                {
                                    [dataKeyPairs addObject:@{relationshipIDKey : obj}];
                                }];

                                relData = dataKeyPairs;
                            }

                        }

                        [self.dataManager importData:relData forRelationshipWithMapping:relationshipMapping onObject:object options:@{RZDataManagerSaveAfterImport : @(NO)} completion:nil];

                    }
                    else
                    {

                        // wrap in a dictionary - we will assume it's the unique identifier
                        // this is for cases when the relationship is specified by one key-value pair instead of fully-qualified
                        // data for the other object

                        NSDictionary *relData = @{relationshipIDKey : value};

                        [self.dataManager importData:relData forRelationshipWithMapping:relationshipMapping onObject:object options:@{RZDataManagerSaveAfterImport : @(NO)} completion:nil];

                    }
                }
                else
                {
                    RZLogDebug(@"Missing relationship id key and/or model id key for relationship object type %@", relationshipMapping.relationshipClassName);
                }
            }
            else
            {

                SEL setter = [[object class] rz_setterForPropertyNamed:relationshipMapping.relationshipPropertyName];
                if (setter)
                {

                    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:setter]];
                    [invocation setTarget:object];
                    [invocation setSelector:setter];
                    [invocation setArgument:&value atIndex:2];

                    @try
                    {
                        [invocation invoke];
                    }
                    @catch (NSException *exception)
                    {
                        RZLogError(@"Error invoking setter %@ on object of class %@: %@", NSStringFromSelector(setter), NSStringFromClass([object class]), exception);
                    }

                }
                else
                {
                    RZLogError(@"Setter not found for property %@ on class %@", relationshipMapping.relationshipPropertyName, NSStringFromClass([object class]));
                }

            }
        }
        else
        {
            RZLogDebug(@"could not find mapping for relationship object type %@ from object type %@", relationshipMapping.relationshipClassName, NSStringFromClass([object class]));
        }
    }
    else if (selectorName != nil)
    {

        SEL importSelector = NSSelectorFromString(selectorName);

        if ([object respondsToSelector:importSelector])
        {

            NSMethodSignature *selectorSig = [object methodSignatureForSelector:importSelector];
            if (selectorSig.numberOfArguments > 2)
            {

                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:selectorSig];
                [invocation setSelector:importSelector];
                [invocation setTarget:object];
                [invocation setArgument:&value atIndex:2];
                if (selectorSig.numberOfArguments > 3)
                {
                    id keyArg = keyPath;
                    [invocation setArgument:&keyArg atIndex:3];
                }

                @try
                {
                    [invocation invoke];
                }
                @catch (NSException *exception)
                {
                    RZLogError(@"Error invoking setter %@ on object of class %@: %@", NSStringFromSelector(importSelector), NSStringFromClass([object class]), exception);
                }

            }
            else
            {
                RZLogDebug(@"Too few arguments for import selector %@ on object of class %@", selectorName, NSStringFromClass([object class]));
            }
        }
        else
        {
            RZLogDebug(@"Unable to perform custom import selector %@ on object of class %@", selectorName, NSStringFromClass([object class]));
        }

    }
    else
    {
        // import as a property
        [self setPropertyValue:value onObject:object fromKeyPath:keyPath withMapping:mapping];
    }
}

- (void)setPropertyValue:(id)value
                onObject:(NSObject <RZDataManagerModelObject> *)object
             fromKeyPath:(NSString *)keyPath
             withMapping:(RZDataManagerModelObjectMapping *)mapping
{
    NSString *propertyName = [mapping modelPropertyNameForDataKey:keyPath];

    // Attempt explicit conversion
    NSString *conversion = [[object class] rz_dataTypeForPropertyNamed:propertyName];

    // If it's a scalar type, KVC should implicitly handle the conversion
    BOOL isNSValue = [value isKindOfClass:[NSValue class]];
    if (!isNSValue || !rz_isScalarDataType(conversion))
    {

        // perform NSObject type conversion
        if (conversion != nil && value != nil)
        {

            // TODO: Format overrides
            NSString *format = mapping.dateFormat;
            value = [self convertValue:value toType:conversion withFormat:format];
        }

    }

    @try
    {
        if (value != nil)
        {
            // this will handle type conversion from NSNumber to scalars
            [object setValue:value forKey:propertyName];
        }
        else
        {
            // Need to use invocation to set value to nil
            SEL setter = [[object class] rz_setterForPropertyNamed:propertyName];
            if (setter)
            {
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:setter]];
                [invocation setSelector:setter];
                [invocation setTarget:object];
                [invocation setArgument:&value atIndex:2];
                [invocation invoke];
            }
        }
    }
    @catch (NSException *exception)
    {
        RZLogError(@"Error setting value for key %@ on object of class %@: %@", propertyName, NSStringFromClass([object class]), exception);
    }

}

- (id)convertValue:(id)value toType:(NSString *)conversionType withFormat:(NSString *)format
{
    id newValue = value;

    if ([conversionType isEqualToString:kRZDataTypeNSDate])
    {
        if ([value isKindOfClass:[NSString class]])
        {

            @synchronized (self.dateFormatter)
            {
                if (format)
                {
                    [self.dateFormatter setDateFormat:format];
                }
                else
                {
                    [self.dateFormatter setDateFormat:self.defaultDateFormat];
                }

                newValue = [self.dateFormatter dateFromString:(NSString *)value];
            }
        }
        else if ([value isKindOfClass:[NSNumber class]])
        {

            // Assuming it's seconds since epoch
            newValue = [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)value doubleValue]];
        }
        else if (![value isKindOfClass:[NSDate class]])
        {
            RZLogDebug(@"Object of class %@ cannot be converted to NSDate", NSStringFromClass([value class]));
        }
    }
    else if ([conversionType isEqualToString:kRZDataTypeNSNumber])
    {
        if ([value isKindOfClass:[NSString class]])
        {
            @synchronized (self.numberFormatter)
            {
                newValue = [self.numberFormatter numberFromString:(NSString *)value];
            }
        }
        else if (![value isKindOfClass:[NSNumber class]])
        {
            RZLogDebug(@"Object of class %@ cannot be converted to NSNumber", NSStringFromClass([value class]));
        }
    }
    else if ([conversionType isEqualToString:kRZDataTypeNSString])
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

- (id)init
{
    self = [super init];
    if (self)
    {
        self.insertedObjectIndices = [NSMutableArray arrayWithCapacity:16];
        self.removedObjectIndices  = [NSMutableArray arrayWithCapacity:16];
        self.movedObjectIndices    = [NSMutableArray arrayWithCapacity:16];
    }
    return self;
}

@end
