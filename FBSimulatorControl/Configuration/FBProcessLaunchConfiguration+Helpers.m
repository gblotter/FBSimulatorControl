/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBProcessLaunchConfiguration+Helpers.h"

#import "FBProcessLaunchConfiguration+Private.h"
#import "FBSimulator.h"
#import "FBSimulatorApplication.h"
#import "FBSimulatorControlStaticConfiguration.h"
#import "FBSimulatorError.h"

@implementation FBProcessLaunchConfiguration (Helpers)

- (instancetype)withDiagnosticEnvironment
{
  FBProcessLaunchConfiguration *configuration = [self copy];

  // It looks like DYLD_PRINT is not currently working as per TN2239.
  NSDictionary *diagnosticEnvironment = @{
    @"OBJC_PRINT_LOAD_METHODS" : @"YES",
    @"OBJC_PRINT_IMAGES" : @"YES",
    @"OBJC_PRINT_IMAGE_TIMES" : @"YES",
    @"DYLD_PRINT_STATISTICS" : @"1",
    @"DYLD_PRINT_ENV" : @"1",
    @"DYLD_PRINT_LIBRARIES" : @"1"
  };
  NSMutableDictionary *environment = [[self environment] mutableCopy];
  [environment addEntriesFromDictionary:diagnosticEnvironment];
  configuration.environment = [environment copy];
  return configuration;
}

@end

@implementation FBApplicationLaunchConfiguration (Helpers)

- (instancetype)withXCTestBundle:(NSString *)xcTestBundlePath error:(NSError **)error
{
  if (![NSFileManager.defaultManager fileExistsAtPath:xcTestBundlePath]) {
    return [[FBSimulatorError describeFormat:@"XCTest Bundle does not exist at path %@", xcTestBundlePath] fail:error];
  }

  NSString *ideBundleInjectionPath = [FBSimulatorControlStaticConfiguration.developerDirectory
    stringByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks/IDEBundleInjection.framework"];

  if (![NSFileManager.defaultManager fileExistsAtPath:ideBundleInjectionPath]) {
    return [[FBSimulatorError describeFormat:@"IDEBundleInjection.framework does not exist at path %@", ideBundleInjectionPath] fail:error];
  }

  NSDictionary *xcTestEnvironment = @{
    @"XCInjectBundle" : xcTestBundlePath,
    @"XCInjectBundleInto" : self.application.binary.path,
    @"DYLD_INSERT_LIBRARIES" :  ideBundleInjectionPath
  };

  FBApplicationLaunchConfiguration *configuration = [self copy];

  NSMutableDictionary *environment = [[self environment] mutableCopy];
  [environment addEntriesFromDictionary:xcTestEnvironment];
  configuration.environment = [environment copy];
  configuration.arguments = @[@"-XCTest", @"All", ideBundleInjectionPath];
  return configuration;
}

@end
