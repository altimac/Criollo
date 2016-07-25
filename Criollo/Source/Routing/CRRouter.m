//
//  CRRoutingCenter.m
//  Criollo
//
//  Created by Cătălin Stan on 19/07/16.
//  Copyright © 2016 Cătălin Stan. All rights reserved.
//

#import "CRRouter.h"
#import "CRRouter_Internal.h"
#import "CRRoute.h"
#import "CRRoute_Internal.h"
#import "CRRouteMatchingResult.h"
#import "CRRouteMatchingResult_Internal.h"
#import "CRServer.h"
#import "CRMessage.h"
#import "CRMessage_Internal.h"
#import "CRRequest.h"
#import "CRRequest_Internal.h"
#import "CRResponse.h"
#import "CRResponse_Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface CRRouter ()

@property (nonatomic, strong, readonly) NSMutableArray<CRRoute *> * routes;

@end

NS_ASSUME_NONNULL_END

@implementation CRRouter

+ (CRRouteBlock)errorHandlingBlockWithStatus:(NSUInteger)statusCode error:(NSError *)error {
    return ^(CRRequest *request, CRResponse *response, CRRouteCompletionBlock completionHandler) {
        [response setStatusCode:statusCode description:nil];
        [response setValue:@"text/plain; charset=utf-8" forHTTPHeaderField:@"Content-type"];

        NSMutableString* responseString = [NSMutableString string];

#if DEBUG
        NSError* err;
        if (error == nil) {
            NSMutableDictionary* mutableUserInfo = [NSMutableDictionary dictionaryWithCapacity:2];
            NSString* errorDescription;
            switch (statusCode) {
                case 404:
                    errorDescription = [NSString stringWithFormat:NSLocalizedString(@"No routes defined for “%@%@%@”",), NSStringFromCRHTTPMethod(request.method), request.URL.path, [request.URL.path hasSuffix:CRPathSeparator] ? @"" : CRPathSeparator];
                    break;
            }
            if ( errorDescription ) {
                mutableUserInfo[NSLocalizedDescriptionKey] = errorDescription;
            }
            mutableUserInfo[NSURLErrorFailingURLErrorKey] = request.URL;
            err = [NSError errorWithDomain:CRServerErrorDomain code:statusCode userInfo:mutableUserInfo];
        } else {
            err = error;
        }

        // Error details
        [responseString appendFormat:@"%@ %lu\n%@\n", err.domain, (long)err.code, err.localizedDescription];

        // Error user-info
        if ( err.userInfo.count > 0 ) {
            [responseString appendString:@"\nUser Info\n"];
            [err.userInfo enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [responseString appendFormat:@"%@: %@\n", key, obj];
            }];
        }

        // Stack trace
        [responseString appendString:@"\nStack Trace\n"];
        [[NSThread callStackSymbols] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [responseString appendFormat:@"%@\n", obj];
        }];
#else
        [responseString appendFormat:@"Cannot %@ %@", NSStringFromCRHTTPMethod(request.method), request.URL.path];
#endif

        [response setValue:@(responseString.length).stringValue forHTTPHeaderField:@"Content-Length"];
        [response sendString:responseString];
        
        completionHandler();
    };
}

- (instancetype)init {
    self = [super init];
    if ( self != nil ) {
        _routes = [NSMutableArray array];
        _notFoundBlock = [CRRouter errorHandlingBlockWithStatus:404 error:nil];
    }
    return self;
}

#pragma mark - Block Routes

- (void)addBlock:(CRRouteBlock)block {
    [self addBlock:block forPath:nil method:CRHTTPMethodAll recursive:NO];
}

- (void)addBlock:(CRRouteBlock)block forPath:(NSString*)path {
    [self addBlock:block forPath:path method:CRHTTPMethodAll recursive:NO];
}

- (void)addBlock:(CRRouteBlock)block forPath:(NSString *)path method:(CRHTTPMethod)method {
    [self addBlock:block forPath:path method:method recursive:NO];
}

- (void)addBlock:(CRRouteBlock)block forPath:(NSString *)path method:(CRHTTPMethod)method recursive:(BOOL)recursive {
    CRRoute* route = [[CRRoute alloc] initWithBlock:block method:method path:path recursive:recursive];
    [self addRoute:route];
}

- (void)add:(NSString *)path block:(CRRouteBlock)block {
    [self add:path block:block recursive:NO];
}

- (void)add:(NSString *)path block:(CRRouteBlock)block recursive:(BOOL)recursive {
    [self addBlock:block forPath:path method:CRHTTPMethodAll recursive:YES];
}

- (void)get:(NSString *)path block:(CRRouteBlock)block {
    [self get:path block:block recursive:NO];
}

- (void)get:(NSString *)path block:(CRRouteBlock)block recursive:(BOOL)recursive {
    [self addBlock:block forPath:path method:CRHTTPMethodGet recursive:recursive];
}

- (void)post:(NSString *)path block:(CRRouteBlock)block {
    [self post:path block:block recursive:NO];
}

- (void)post:(NSString *)path block:(CRRouteBlock)block recursive:(BOOL)recursive {
    [self addBlock:block forPath:path method:CRHTTPMethodPost recursive:recursive];
}

- (void)put:(NSString *)path block:(CRRouteBlock)block {
    [self put:path block:block recursive:NO];
}

- (void)put:(NSString *)path block:(CRRouteBlock)block recursive:(BOOL)recursive {
    [self addBlock:block forPath:path method:CRHTTPMethodPut recursive:recursive];
}

- (void)delete:(NSString *)path block:(CRRouteBlock)block {
    [self delete:path block:block recursive:NO];
}

- (void)delete:(NSString *)path block:(CRRouteBlock)block recursive:(BOOL)recursive {
    [self addBlock:block forPath:path method:CRHTTPMethodDelete recursive:recursive];
}

#pragma mark - Route Controller Routes

- (void)addController:(__unsafe_unretained Class)controllerClass forPath:(NSString *)path {
    [self addController:controllerClass forPath:path method:CRHTTPMethodAll recursive:NO];
}

- (void)addController:(__unsafe_unretained Class)controllerClass forPath:(NSString *)path method:(CRHTTPMethod)method {
    [self addController:controllerClass forPath:path method:method recursive:NO];
}

- (void)addController:(__unsafe_unretained Class)controllerClass forPath:(NSString *)path method:(CRHTTPMethod)method recursive:(BOOL)recursive {
    CRRoute* route = [[CRRoute alloc] initWithControllerClass:controllerClass method:method path:path recursive:recursive];
    [self addRoute:route];
}


#pragma mark - View Controller Routes

- (void)addViewController:(__unsafe_unretained Class)viewControllerClass withNibName:(NSString *)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil forPath:(NSString *)path {
    [self addViewController:viewControllerClass withNibName:nibNameOrNil bundle:nibBundleOrNil forPath:path method:CRHTTPMethodAll recursive:NO];
}

- (void)addViewController:(__unsafe_unretained Class)viewControllerClass withNibName:(NSString *)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil forPath:(NSString *)path method:(CRHTTPMethod)method {
    [self addViewController:viewControllerClass withNibName:nibNameOrNil bundle:nibBundleOrNil forPath:path method:method recursive:NO];
}

- (void)addViewController:(__unsafe_unretained Class)viewControllerClass withNibName:(NSString *)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil forPath:(NSString *)path method:(CRHTTPMethod)method recursive:(BOOL)recursive {
    CRRoute* route = [[CRRoute alloc] initWithViewControllerClass:viewControllerClass nibName:nibNameOrNil bundle:nibBundleOrNil method:method path:path recursive:recursive];
    [self addRoute:route];
}



#pragma mark - General Routes

- (void)addRoute:(CRRoute*)route {
    [self.routes addObject:route];
}

- (NSArray<CRRouteMatchingResult *> *)routesForPath:(NSString*)path method:(CRHTTPMethod)method {
    NSMutableArray<CRRouteMatchingResult *> * routes = [NSMutableArray array];
    [self.routes enumerateObjectsUsingBlock:^(CRRoute * _Nonnull route, NSUInteger idx, BOOL * _Nonnull stop) {

        // Bailout early if method does not match
        if ( route.method != method && route.method != CRHTTPMethodAll ) {
            return;
        }

        // Boilout early if route is valid for all paths or path matches exaclty
        if ( route.path == nil || [route.path isEqualToString:path] ) {
            [routes addObject:[CRRouteMatchingResult routeMatchingResultWithRoute:route matches:nil]];
            return;
        }

        // If route is recursive just check that the path start with the route path
        if ( route.recursive && [path hasPrefix:route.path] ) {
            [routes addObject:[CRRouteMatchingResult routeMatchingResultWithRoute:route matches:nil]];
            return;
        }

        // If the route regex matches
        if ( !route.pathRegex ) {
            return;
        }

        NSArray* matches = [route processMatchesInPath:path];
        if ( matches.count > 0 ) {
            [routes addObject:[CRRouteMatchingResult routeMatchingResultWithRoute:route matches:matches]];
        }
    }];

//    NSLog(@"%s %@", __PRETTY_FUNCTION__, routes);
    return routes;
}

- (void)executeRoutes:(NSArray<CRRouteMatchingResult *> *)routes forRequest:(CRRequest *)request response:(CRResponse *)response {
    [self executeRoutes:routes forRequest:request response:response withNotFoundBlock:nil];
}

- (void)executeRoutes:(NSArray<CRRouteMatchingResult *> *)routes forRequest:(CRRequest *)request response:(CRResponse *)response withNotFoundBlock:(CRRouteBlock)notFoundBlock {
    if ( !notFoundBlock ) {
        notFoundBlock = [CRRouter errorHandlingBlockWithStatus:404 error:nil];
    }

    if ( routes.count == 0 ) {
        CRRoute* defaultRoute = [[CRRoute alloc] initWithBlock:notFoundBlock method:CRHTTPMethodAll path:nil recursive:NO];
        routes = @[[CRRouteMatchingResult routeMatchingResultWithRoute:defaultRoute matches:nil]];
    }

    __block BOOL shouldStopExecutingBlocks = NO;
    __block NSUInteger currentRouteIndex = 0;
    while (!shouldStopExecutingBlocks && currentRouteIndex < routes.count ) {
        shouldStopExecutingBlocks = YES;
        CRRouteMatchingResult* result = routes[currentRouteIndex];
        if ( result.matches.count > 0 ) {
            [result.route.pathKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
                [request setQuery:(result.matches[idx] ? : @"") forKey:key];
            }];            
        }
        result.route.block (request, response, ^{
            shouldStopExecutingBlocks = NO;
            currentRouteIndex++;
        });
    }
}

@end