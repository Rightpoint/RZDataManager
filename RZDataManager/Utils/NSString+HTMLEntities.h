//
//  NSString+HTMLEntities.h
//  RZDataManager
//
//  Created by Nick Donaldson on 05/14/2013
//  Copyright 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const kRZHTMLStringUtilsRegularFont;
extern NSString* const kRZHTMLStringUtilsBoldFont;
extern NSString* const kRZHTMLStringUtilsItalicFont;

@interface NSString (HTMLEntities)

- (NSString *)stringByDecodingHTMLEntities;
- (NSString *)stringByRemovingHTMLTags;

//! Put each type of font into font dictionary. If not found will default to system fonts.
- (NSAttributedString*)attributedStringByDecodingHTMLTagsWithFontDictionary:(NSDictionary*)fontDict;

@end
