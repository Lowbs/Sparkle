//
//  SUCommandLineDriver.m
//  sparkle-cli
//
//  Created by Mayur Pawashe on 4/10/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#import "SPUCommandLineDriver.h"
#import <Sparkle/Sparkle.h>
#import "SPUCommandLineUserDriver.h"

void _SULogDisableStandardErrorStream(void);

@interface SPUCommandLineDriver () <SPUUpdaterDelegate>

@property (nonatomic, readonly) SPUUpdater *updater;
@property (nonatomic, readonly) BOOL verbose;
@property (nonatomic) BOOL probingForUpdates;
@property (nonatomic, readonly) BOOL interactive;

@end

@implementation SPUCommandLineDriver

@synthesize updater = _updater;
@synthesize verbose = _verbose;
@synthesize probingForUpdates = _probingForUpdates;
@synthesize interactive = _interactive;

- (instancetype)initWithUpdateBundlePath:(NSString *)updateBundlePath applicationBundlePath:(nullable NSString *)applicationBundlePath updatePermission:(nullable SPUUpdatePermission *)updatePermission deferInstallation:(BOOL)deferInstallation interactiveInstallation:(BOOL)interactiveInstallation verbose:(BOOL)verbose
{
    self = [super init];
    if (self != nil) {
        NSBundle *updateBundle = [NSBundle bundleWithPath:updateBundlePath];
        if (updateBundle == nil) {
            return nil;
        }
        
        NSBundle *applicationBundle = nil;
        if (applicationBundlePath == nil) {
            applicationBundle = updateBundle;
        } else {
            applicationBundle = [NSBundle bundleWithPath:(NSString * _Nonnull)applicationBundlePath];
            if (applicationBundle == nil) {
                return nil;
            }
        }
        
        _verbose = verbose;
        _interactive = interactiveInstallation;
        
#ifndef DEBUG
        _SULogDisableStandardErrorStream();
#endif
        
        id <SPUUserDriver> userDriver = [[SPUCommandLineUserDriver alloc] initWithApplicationBundle:applicationBundle updatePermission:updatePermission deferInstallation:deferInstallation verbose:verbose];
        _updater = [[SPUUpdater alloc] initWithHostBundle:updateBundle applicationBundle:applicationBundle userDriver:userDriver delegate:self];
    }
    return self;
}

- (void)updater:(SPUUpdater *)__unused updater willScheduleUpdateCheckAfterDelay:(NSTimeInterval)delay __attribute__((noreturn))
{
    if (self.verbose) {
        fprintf(stderr, "Last update check occurred too soon. Try again after %0.0f second(s).", delay);
    }
    exit(EXIT_SUCCESS);
}

- (void)updaterWillIdleSchedulingUpdates:(SPUUpdater *)__unused updater __attribute__((noreturn))
{
    if (self.verbose) {
        fprintf(stderr, "Automatic update checks are disabled. Exiting.\n");
    }
    exit(EXIT_SUCCESS);
}

- (BOOL)updaterShouldAllowInstallerInteraction:(SPUUpdater *)__unused updater
{
    // If the installation is interactive, we can show an authorization prompt for requesting additional privileges,
    // otherwise we should have the installer inherit the updater's privileges.
    return self.interactive;
}

// In case we find an update during probing, otherwise we leave this to the user driver
- (void)updater:(SPUUpdater *)__unused updater didFindValidUpdate:(SUAppcastItem *)__unused item
{
    if (self.probingForUpdates) {
        if (self.verbose) {
            fprintf(stderr, "Update available!\n");
        }
        exit(EXIT_SUCCESS);
    }
}

// In case we fail during probing, otherwise we leave error handling to the user driver
- (void)updaterDidNotFindUpdate:(SPUUpdater *)__unused updater __attribute__((noreturn))
{
    if (self.verbose) {
        fprintf(stderr, "No update available!\n");
    }
    exit(EXIT_FAILURE);
}

// In case we fail during probing, otherwise we leave error handling to the user driver
- (void)updater:(SPUUpdater *)__unused updater didAbortWithError:(NSError *)error __attribute__((noreturn))
{
    if (self.verbose) {
        fprintf(stderr, "Aborted update with error (%ld): %s\n", (long)error.code, error.localizedDescription.UTF8String);
    }
    exit(EXIT_FAILURE);
}

- (BOOL)updaterShouldDownloadReleaseNotes:(SPUUpdater *)__unused updater
{
    return self.verbose;
}

- (void)startUpdater
{
    NSError *updaterError = nil;
    if (![self.updater startUpdater:&updaterError]) {
        fprintf(stderr, "Error: Failed to initialize updater with error (%ld): %s\n", updaterError.code, updaterError.localizedDescription.UTF8String);
        exit(EXIT_FAILURE);
    }
}

- (void)runAndCheckForUpdatesNow:(BOOL)checkForUpdatesNow
{
    if (checkForUpdatesNow) {
        // When we start the updater, this scheduled check will start afterwards too
        [self.updater checkForUpdates];
    }
    
    [self startUpdater];
}

- (void)probeForUpdates
{
    // When we start the updater, this info check will start afterwards too
    self.probingForUpdates = YES;
    [self.updater checkForUpdateInformation];
    [self startUpdater];
}

@end
