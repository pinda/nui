//
//  NUIKey.h
//  Gibbon
//
//  Created by Joeri Djojosoeparto on 1/16/13.
//  Copyright (c) 2013 Joeri Djojosoeparto. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreParse.h"

@interface NUIKey : NSObject <CPParseResult>

@property (readwrite, copy) NSString *key;

@end
