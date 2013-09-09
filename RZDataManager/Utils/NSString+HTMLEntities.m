//
//  NSString+HTMLEntities.m
//  Raizlabs
//
//  Created by Nick Donaldson on 05/14/2013
//  Copyright 2013 Raizlabs. All rights reserved.
//
//  NSScanner code adapted from Stackoverflow user Walty:
//  http://stackoverflow.com/questions/1105169/html-character-decoding-in-objective-c-cocoa-touch


#import "NSString+HTMLEntities.h"

NSString* const kRZHTMLStringUtilsRegularFont   = @"RegularFont";
NSString* const kRZHTMLStringUtilsBoldFont      = @"BoldFont";
NSString* const kRZHTMLStringUtilsItalicFont    = @"ItalicFont";

@implementation NSString (HTMLEntities)

- (NSString *)stringByDecodingHTMLEntities {
	
	NSUInteger myLength = [self length];
	NSUInteger ampIndex = [self rangeOfString:@"&" options:NSLiteralSearch].location;
	
	// Short-circuit if there are no ampersands.
	if (ampIndex == NSNotFound) {
		return self;
	}
	
	// Make result string with some extra capacity.
	NSMutableString *result = [NSMutableString stringWithCapacity:(NSUInteger)(myLength * 1.25)];
	
	// First iteration doesn't need to scan to & since we did that already, but for code simplicity's sake we'll do it again with the scanner.
	NSScanner *scanner = [NSScanner scannerWithString:self];
	
	[scanner setCaseSensitive:YES];
	[scanner setCharactersToBeSkipped:nil];
	
	NSCharacterSet *boundaryCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r;"];
	
	do {
		// Scan up to the next entity or the end of the string.
		NSString *nonEntityString;
		if ([scanner scanUpToString:@"&" intoString:&nonEntityString]) {
			[result appendString:nonEntityString];
		}
		if ([scanner isAtEnd]) {
			return result;
		}
		// Scan either a HTML or numeric character entity reference.
		if ([scanner scanString:@"&amp;" intoString:NULL])
			[result appendString:@"&"];
		else if ([scanner scanString:@"&apos;" intoString:NULL])
			[result appendString:@"'"];
		else if ([scanner scanString:@"&quot;" intoString:NULL])
			[result appendString:@"\""];
		else if ([scanner scanString:@"&lt;" intoString:NULL])
			[result appendString:@"<"];
		else if ([scanner scanString:@"&gt;" intoString:NULL])
			[result appendString:@">"];
		else if ([scanner scanString:@"&reg;" intoString:NULL])
			[result appendString:@"®"];
		else if ([scanner scanString:@"&eacute;" intoString:NULL])
			[result appendString:@"é"];
		else if ([scanner scanString:@"&egrave;" intoString:NULL])
			[result appendString:@"è"];
		else if ([scanner scanString:@"&Eacute;" intoString:NULL])
			[result appendString:@"É"];
		else if ([scanner scanString:@"&Egrave;" intoString:NULL])
			[result appendString:@"È"];
		else if ([scanner scanString:@"&#" intoString:NULL]) {
            
			BOOL gotNumber;
			unsigned charCode;
			NSString *xForHex = @"";
			
			// Is it hex or decimal?
			if ([scanner scanString:@"x" intoString:&xForHex]) {
				gotNumber = [scanner scanHexInt:&charCode];
			}
			else {
				gotNumber = [scanner scanInt:(int*)&charCode];
			}
			
			if (gotNumber) {
				[result appendFormat:@"%C", (unsigned short)charCode];
				[scanner scanString:@";" intoString:NULL];
			}
			else {
				NSString *unknownEntity = @"";				
				[scanner scanUpToCharactersFromSet:boundaryCharacterSet intoString:&unknownEntity];
				[result appendFormat:@"&#%@%@", xForHex, unknownEntity];
				NSLog(@"Expected numeric character entity but got &#%@%@;", xForHex, unknownEntity);
			}
			
		}
		else {
			NSString *amp;
			[scanner scanString:@"&" intoString:&amp];
			[result appendString:amp];
		}
	}
	while (![scanner isAtEnd]);
	
	return result;
	
}

- (NSString*)stringByRemovingHTMLTags
{
    // We can only really decode \n from <br>, otherwise just remove the tag altogether
    NSString *s = [self copy];
    
    // replace <br> and <br \> with newline
    s = [s stringByReplacingOccurrencesOfString:@"<br>" withString:@"\n"];
    s = [s stringByReplacingOccurrencesOfString:@"<br \\>" withString:@"\n"];
    
    // remove other tags
    NSRange r;
    while ((r = [s rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
        s = [s stringByReplacingCharactersInRange:r withString:@""];
    return s;
}

- (NSAttributedString*)attributedStringByDecodingHTMLTagsWithFontDictionary:(NSDictionary *)fontDict
{
    
    // Get fonts
    
    UIFont *regularFont = [fontDict objectForKey:kRZHTMLStringUtilsRegularFont];
    UIFont *boldFont = [fontDict objectForKey:kRZHTMLStringUtilsBoldFont];
    UIFont *italicFont = [fontDict objectForKey:kRZHTMLStringUtilsItalicFont];
    
    if (regularFont == nil){
        regularFont = [UIFont systemFontOfSize:14];
    }
    
    if (boldFont == nil){
        boldFont = [UIFont boldSystemFontOfSize:14];
    }
    
    if (italicFont == nil){
        italicFont = [UIFont italicSystemFontOfSize:14];
    }

    // Create string
    
    NSString *s = [self copy];
    
    // replace <br> and <br \> with newline
    s = [s stringByReplacingOccurrencesOfString:@"<br>" withString:@"\n"];
    s = [s stringByReplacingOccurrencesOfString:@"<br \\>" withString:@"\n"];
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] init];
    
    NSMutableDictionary *baseAttrib = [NSMutableDictionary dictionaryWithDictionary:@{NSFontAttributeName : regularFont}];
    NSMutableDictionary *boldAttrib = [NSMutableDictionary dictionaryWithDictionary:@{NSFontAttributeName : boldFont}];
    NSMutableDictionary *italicAttrib = [NSMutableDictionary dictionaryWithDictionary:@{NSFontAttributeName : italicFont}];

    
    if ([s rangeOfString:@"<" options:NSLiteralSearch].location == NSNotFound){
        
        NSAttributedString *fullString = [[NSAttributedString alloc] initWithString:s attributes:baseAttrib];
        [attributedString appendAttributedString:fullString];
    }
    else{
        
        NSScanner *scanner = [[NSScanner alloc] initWithString:s];
        
        [scanner setCaseSensitive:YES];
        [scanner setCharactersToBeSkipped:nil];
    
        do {
                        
            NSString *plainString;
            
            if ([scanner scanUpToString:@"<" intoString:&plainString]){
                [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:plainString attributes:baseAttrib]];
            }
            
            if ([scanner isAtEnd]) break;
            
            // try to scan tags we know about
            // TODO: other tags?
            if ([scanner scanString:@"<strong>" intoString:NULL]){
                
                NSString *boldString;
                if ([scanner scanUpToString:@"</strong>" intoString:&boldString]){
                    
                    [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:boldString attributes:boldAttrib]];
                    
                    [scanner scanString:@"</strong>" intoString:NULL];
                }
                else{
                    NSLog(@"Error: unmatched <strong> tag");
                    break;
                }
                
            }
            else if([scanner scanString:@"<b>" intoString:NULL]){
                
                NSString *boldString;
                if ([scanner scanUpToString:@"</b>" intoString:&boldString]){
                    
                    [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:boldString attributes:boldAttrib]];
                    
                    [scanner scanString:@"</b>" intoString:NULL];
                }
                else{
                    NSLog(@"Error: unmatched <b> tag");
                    break;
                }
                
            }
            else if ([scanner scanString:@"<i>" intoString:NULL]){
                
                NSString *italicString;
                if ([scanner scanUpToString:@"</i>" intoString:&italicString]){
                    
                    [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:italicString attributes:italicAttrib]];
                    
                    [scanner scanString:@"</i>" intoString:NULL];
                }
                else{
                    NSLog(@"Error: unmatched <i> tag");
                    break;
                }
                
            }
            else{
                [scanner scanString:@"<" intoString:NULL];
                
                if ([scanner scanUpToString:@">" intoString:NULL]){
                    [scanner scanString:@">" intoString:NULL];
                }
            }
            

        } while (![scanner isAtEnd]);
        
    }
    
    return attributedString;
}

@end
