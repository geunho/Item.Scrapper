//
//  ShareViewController.m
//  Scrapper.Share
//
//  Created by Geunho Khim on 2014. 10. 20..
//  Copyright (c) 2014년 com.ebay.kr.gkhim. All rights reserved.
//

#import "ShareViewController.h"
#import "ItemEntity.h"

@interface ShareViewController ()

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;

@end


@implementation ShareViewController

- (BOOL)isContentValid {
    return YES;
}

- (void)didSelectPost {
    NSExtensionContext *context = [self extensionContext];
    NSExtensionItem *inputItem = [context inputItems].firstObject;
    NSItemProvider *provider = inputItem.attachments.firstObject;

    if([self.contentText containsString:@"http://"]) {
        NSString *urlString = [self getUrlStringFromContentText:self.contentText];
        [self requestScrapperWithUrlString:urlString];
        [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
    } else {
        [provider loadItemForTypeIdentifier:@"public.url" options:nil completionHandler:^(NSURL *url, NSError *error) {
            NSString *urlString = url.absoluteString;
            [self requestScrapperWithUrlString:urlString];
            [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
        }];
    }
}

- (NSArray *)configurationItems {
    [self setupManagedObjectContext];
     
    return @[];
}

- (NSString *)getUrlStringFromContentText:(NSString *)contentText {
    NSString *parsedUrl = [contentText componentsSeparatedByString:@"http://"][1];
    NSString *returnUrl = [NSString stringWithFormat:@"http://%@", parsedUrl];
        
    return returnUrl;
}

- (void)requestScrapperWithUrlString:(NSString *)urlString {
    NSString *formatUrl = [urlString stringByReplacingOccurrencesOfString:@"&" withString:@""];
    NSString *requestString = [NSString stringWithFormat:SCRAPPER_HOST@"/~geunho/run_scrapper.py?startUrl=%@", formatUrl];
    requestString = [requestString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest * urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:requestString]];

    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest
                                          returningResponse:&response
                                                      error:&error];
    if (!error) {
        [self parseResponseDataAndInsert:data url:urlString];
    } else {
        NSLog(@"error occured: %@", error.description);
        [self showAlert];
    }
}

- (void)showAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:@"Can not scrap the item. Please try again."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              [alert dismissViewControllerAnimated:YES completion:nil];
                                                          }];
    [alert addAction:defaultAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)parseResponseDataAndInsert:(NSData *)responseData url:(NSString *)urlString {
    NSError* error;
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:responseData
                                                         options:kNilOptions
                                                           error:&error];
    if(error || [json count] == 0) {
        NSLog(@"Json serialization exception: %@", error);        
        [self showAlert];
    }
    else {
    
        ItemEntity *item = [NSEntityDescription insertNewObjectForEntityForName:@"ItemEntity"
                                                     inManagedObjectContext:self.managedObjectContext];
    
        item.linkUrl = urlString;
        NSString *imageUrl = [json objectForKey:@"imageUrl"];
        item.imageUrl = imageUrl;
        NSString *title = [json objectForKey:@"title"];
        item.title = title;
        NSNumber *price = [json objectForKey:@"price"];
        item.price = price;
        NSString *formatPrice = [json objectForKey:@"formatPrice"];
        item.formatPrice = formatPrice;
        item.timestamp = [NSDate date];
    
        if ([self.managedObjectContext save:&error]) {
            NSLog(@"Item Saved");
        }
        else {
            NSLog(@"Item Not Saved.");
            [self showAlert];
        }
    }
}

- (void)setupManagedObjectContext {
    NSURL *directory = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.ebay.kr.gkhim.scrapper"];
    NSURL *storeURL = [directory  URLByAppendingPathComponent:@"ItemScrapper.sqlite"];
    
    self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"ItemScrapper" withExtension:@"momd"];
    self.managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    self.managedObjectContext.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    
    NSError *error;
    [self.managedObjectContext.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                       configuration:nil
                                                                                 URL:storeURL
                                                                             options:nil
                                                                               error:&error];
    if (error) {
        NSLog(@"error: %@", error);
        [self showAlert];
    }
    
    self.managedObjectContext.undoManager = [[NSUndoManager alloc] init];
}



@end
