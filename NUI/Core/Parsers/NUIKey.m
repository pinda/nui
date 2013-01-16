//
//  NUIKey.m
//  Gibbon
//
//  Created by Joeri Djojosoeparto on 1/16/13.
//  Copyright (c) 2013 Joeri Djojosoeparto. All rights reserved.
//

#import "NUIKey.h"

@implementation NUIKey

@synthesize key;

- (id)initWithSyntaxTree:(CPSyntaxTree *)syntaxTree
{
  self = [super init];
  
  if (nil != self)
  {
    [self setKey:[(CPIdentifierToken*)[[syntaxTree children] objectAtIndex:0] identifier]];
  }
  
  return self;
}

@end
