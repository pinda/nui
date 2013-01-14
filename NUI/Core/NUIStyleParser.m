//
//  NUIStyleParser.m
//  NUIDemo
//
//  Created by Tom Benner on 12/4/12.
//  Copyright (c) 2012 Tom Benner. All rights reserved.
//

// N.B.: This would ideally be implemented with something like a lexical analyzer generator, but
// they all seem to have licenses that wouldn't be suitable for use in the App Store.

#import "NUIStyleParser.h"

#import "CoreParse.h"

@interface NUIStyleParser () <CPTokeniserDelegate, CPParserDelegate>

@property (readwrite, strong) CPTokeniser *tokeniser;
@property (readwrite, strong) CPParser *parser;

@end

@implementation NUIStyleParser {
  NSCharacterSet *symbolsSet;
}

@synthesize tokeniser;
@synthesize parser;

- (id)init
{
  self = [super init];
  
  if (nil != self)
  {
    symbolsSet = [NSCharacterSet characterSetWithCharactersInString:@"*[]{}.;@-!=<>:!#%"];
    
    NSDictionary *pt = [NSKeyedUnarchiver unarchiveObjectWithFile:[[NSBundle mainBundle] pathForResource:@"parser" ofType:@"osp"]];
    [self setTokeniser:[pt objectForKey:@"tokeniser"]];
    [self setParser:[pt objectForKey:@"parser"]];
    [[self tokeniser] setDelegate:self];
    [[self parser] setDelegate:self];
  }
  
  return self;
}

- (BOOL)tokeniser:(CPTokeniser *)tokeniser shouldConsumeToken:(CPToken *)token
{
  return YES;
}

- (NSUInteger)tokeniser:(CPTokeniser *)tokeniser didNotFindTokenOnInput:(NSString *)input position:(NSUInteger)position error:(NSString *__autoreleasing *)errorMessage
{
  NSLog(@"Argh");
  return 1;
}

- (CPRecoveryAction*)parser:(CPParser *)parser didEncounterErrorOnInput:(CPTokenStream *)inputStream expecting:(NSSet *)acceptableTokens
{
  return [CPRecoveryAction recoveryActionStop];
}

- (NSMutableDictionary*)getStylesFromFile:(NSString*)fileName
{
  NSString* path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"nss"];
  NSAssert1(path != nil, @"File \"%@\" does not exist", fileName);
  NSString* content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
  
  CPTokenStream *stream = [[CPTokenStream alloc] init];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^()
                 {
                   @autoreleasepool
                   {
                     [[self tokeniser] tokenise:content into:stream];
                   }
                 });
  return [[self parser] parse:stream];
}

- (NSMutableDictionary*)getStylesFromPath:(NSString*)path
{
    NSString* content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    return [self consolidateRuleSets:[self getRuleSets:content] withTopLevelDeclarations:[self getTopLevelDeclarations:content]];
}

- (NSMutableDictionary*)getTopLevelDeclarations:(NSString*)content
{
    NSString *topLevelContent = [self getTopLevelContent:content];
    return [self getDeclarations:topLevelContent];
}

- (NSMutableArray*)getRuleSets:(NSString*)content
{
    NSString *pattern = @"(\\w[\\w\\s,]+)\\s*\\{([^\\}]+)\\}";
    NSArray *matches = [self getMatches:content withPattern:pattern];
    
    NSMutableArray *ruleSets = [[NSMutableArray alloc] init];
    for (NSTextCheckingResult *match in matches) {
        NSRange range1 = [match rangeAtIndex:1];
        NSRange range2 = [match rangeAtIndex:2];
        NSString *classExpression = [content substringWithRange:range1];
        NSString *declarationsContent = [content substringWithRange:range2];
        NSMutableDictionary *declarations = [self getDeclarations:declarationsContent];
        NSDictionary *ruleSet = [NSDictionary dictionaryWithObjectsAndKeys:
                                 classExpression, @"classExpression",
                                 declarations, @"declarations",
                                 nil];
        [ruleSets addObject:ruleSet];
    }
    return ruleSets;
}

- (NSString*)getTopLevelContent:(NSString*)content
{
    NSString *startOrClose = @"(?:^|\\})";
    NSString *rules = @"(.*?)";
    NSString *endOrOpen = @"(?:$|\\w[\\w\\s,]+\\{[^\\}]+)";
    NSString *pattern = [NSString stringWithFormat:@"%@%@%@", startOrClose, rules, endOrOpen];
    NSArray *matches = [self getMatches:content withPattern:pattern];
    
    NSMutableArray *lineGroups = [[NSMutableArray alloc] init];
    for (NSTextCheckingResult *match in matches) {
        NSRange range = [match rangeAtIndex:1];
        [lineGroups addObject:[content substringWithRange:range]];
    }
    return [lineGroups componentsJoinedByString:@"\n"];
}

- (NSMutableDictionary*)getDeclarations:(NSString*)content
{
    NSString *pattern = @"([^\\s]+):[\\s]*([^;]+);";
    NSArray *matches = [self getMatches:content withPattern:pattern];
    
    NSMutableDictionary *declarations = [[NSMutableDictionary alloc] init];
    for (NSTextCheckingResult *match in matches) {
        NSRange range1 = [match rangeAtIndex:1];
        NSRange range2 = [match rangeAtIndex:2];
        NSString *property = [content substringWithRange:range1];
        NSString *value = [content substringWithRange:range2];
        [declarations setValue:value forKey:property];
    }
    return declarations;
}

- (NSMutableDictionary*)consolidateRuleSets:(NSMutableArray*)ruleSets withTopLevelDeclarations:(NSMutableDictionary*)topLevelDeclarations
{
    NSMutableDictionary *consolidatedRuleSets = [[NSMutableDictionary alloc] init];
    for (NSMutableDictionary *ruleSet in ruleSets) {
        NSString *classExpression = [ruleSet objectForKey:@"classExpression"];
        NSArray *classes = [self getClassesFromClassExpression:classExpression];
        for (NSString *class in classes) {
            if ([consolidatedRuleSets objectForKey:class] == nil) {
                [consolidatedRuleSets setValue:[[NSMutableDictionary alloc] init] forKey:class];
            }
            [self mergeRuleSetIntoConsolidatedRuleSet:ruleSet consolidatedRuleSet:[consolidatedRuleSets objectForKey:class] topLevelDeclarations:topLevelDeclarations];
        }
    }
    return consolidatedRuleSets;
}

- (NSMutableDictionary*)mergeRuleSetIntoConsolidatedRuleSet:(NSMutableDictionary*)ruleSet consolidatedRuleSet:(NSMutableDictionary*)consolidatedRuleSet topLevelDeclarations:(NSMutableDictionary*)topLevelDeclarations
{
    NSMutableDictionary *declarations = [ruleSet objectForKey:@"declarations"];
    for (NSString *property in declarations) {
        NSString *value = [declarations objectForKey:property];
        if ([value hasPrefix:@"@"]) {
            value = [topLevelDeclarations objectForKey:value];
        }
        [consolidatedRuleSet setValue:value forKey:property];
    }
    return consolidatedRuleSet;
}

- (NSArray*)getClassesFromClassExpression:(NSString*)classExpression
{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@",[\\s]*" options:0 error:nil];
    NSString *modifiedClassExpression = [regex stringByReplacingMatchesInString:classExpression options:0 range:NSMakeRange(0, [classExpression length]) withTemplate:@", "];
    NSArray *separatedClasses = [modifiedClassExpression componentsSeparatedByString:@", "];
    NSMutableArray *classes = [[NSMutableArray alloc] init];
    for (NSString *class in separatedClasses) {
        [classes addObject:[class stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
    return classes;
}

- (NSArray*)getMatches:(NSString*)content withPattern:(NSString*)pattern
{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    NSArray *matches = [regex matchesInString:content options:0 range:NSMakeRange(0, [content length])];
    return matches;
}

@end
