//
//  NUISize.m
//  Gibbon
//
//  Created by Joeri Djojosoeparto on 1/16/13.
//  Copyright (c) 2013 Joeri Djojosoeparto. All rights reserved.
//

#import "NUISize.h"

@implementation NUISize

@synthesize value;

- (id)initWithSyntaxTree:(CPSyntaxTree *)syntaxTree
{
  self = [super init];
  
  if (nil != self)
  {
    [self setValue:[[(CPNumberToken*)[[syntaxTree children] objectAtIndex:0] number] floatValue]];
  }
  
  return self;
}


@end
