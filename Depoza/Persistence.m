//
//  SharedManagedObjectContext.m
//  Depoza
//
//  Created by Ivan Magda on 22/12/14.
//  Copyright (c) 2014 Ivan Magda. All rights reserved.
//

#import "Persistence.h"

@implementation Persistence

+ (instancetype)sharedInstance {
    static Persistence *this = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        this = [Persistence new];
    });
    return this;
}

- (instancetype)init {
    if (self = [super init]) {
        NSLog(@"Allocate SharedManagedObjectContext");
        [self managedObjectContext];
    }
    return self;
}

- (void)dealloc {
    NSParameterAssert(false);
}

#pragma mark - Core Data stack

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (NSManagedObjectModel *)managedObjectModel {
    if (!_managedObjectModel) {
        NSString *modelPath = [[NSBundle mainBundle]pathForResource:@"DataModel" ofType:@"momd"];
        NSURL *modelURL = [NSURL fileURLWithPath:modelPath];

        _managedObjectModel = [[NSManagedObjectModel alloc]initWithContentsOfURL:modelURL];
    }
    return _managedObjectModel;
}

- (NSString *)documentsDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths lastObject];
    NSParameterAssert(documentsDirectory);

    return documentsDirectory;
}

- (NSString *)dataStorePath {
    return [[self documentsDirectory]
            stringByAppendingPathComponent:@"DataStore.sqlite"];
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (!_persistentStoreCoordinator) {
        NSURL *storeURL = [NSURL fileURLWithPath:[self dataStorePath]];

        [self initStore:storeURL];

        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]initWithManagedObjectModel:self.managedObjectModel];

        NSError *error;
        if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
            NSLog(@"Error adding persistent store %@, %@", error, [error userInfo]);
            abort();
        }
    }
    return _persistentStoreCoordinator;
}

- (void)initStore:(NSURL *)storeURL {
    if (![[NSFileManager defaultManager] fileExistsAtPath:[storeURL path]]) {
        NSURL *preloadURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"seed" ofType:@"sqlite"]];

        NSError* err;
        if (![[NSFileManager defaultManager] copyItemAtURL:preloadURL toURL:storeURL error:&err]) {
            NSLog(@"Oops, could copy preloaded data");
        } else {
            NSLog(@"Store successfully initialized using the original seed");

            [self performSelector:@selector(setCategoryId) withObject:nil afterDelay:0.1];
        }
    } else {
        NSLog(@"The original seed isn't needed. There is already a backing store.");
    }
}

- (void)setCategoryId {
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"CategoryData"];

    NSError *error = nil;
    NSUInteger numberOfCategories = [self.managedObjectContext countForFetchRequest:fetch error:&error];

    NSParameterAssert(numberOfCategories > 0);

    NSLog(@"Number of categories: %lu", (unsigned long)numberOfCategories);

    if (error) {
        NSLog(@"Could't fetc for count number of categories: %@", [error localizedDescription]);
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:numberOfCategories - 1 forKey:@"categoryId"];
    [defaults synchronize];
}

- (NSManagedObjectContext *)managedObjectContext {
    if (!_managedObjectContext) {
        NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
        if (coordinator) {
            _managedObjectContext = [[NSManagedObjectContext alloc]init];
            [_managedObjectContext setPersistentStoreCoordinator:coordinator];
        }
    }
    return _managedObjectContext;
}

- (NSManagedObjectContext *)createManagedObjectContext {
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] init];

    [managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];

    return managedObjectContext;
}

#pragma mark - Core Data Saving support

- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

@end