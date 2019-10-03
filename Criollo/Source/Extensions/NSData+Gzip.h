//
//  NSData+Gzip.h
//  Criollo
//
//  Created by Aurélien Hugelé on 03/10/2019.
//  Copyright © 2019 Cătălin Stan. All rights reserved.
//

#import <AppKit/AppKit.h>


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (Gzip)

- (nullable NSData *)gzippedDataWithCompressionLevel:(float)level;
- (nullable NSData *)gzippedData;
- (nullable NSData *)gunzippedData;
- (BOOL)isGzippedData;

@end

NS_ASSUME_NONNULL_END
