    //ViewControllers
#import "MainViewController.h"
#import "AddExpenseViewController.h"
#import "DetailExpenseTableViewController.h"
#import "CategoriesContainerViewController.h"
#import "MainTableViewProtocolsImplementer.h"
#import "SelectMonthViewController.h"
    //View
#import "TitleViewButton.h"

    //CoreData
#import "Expense.h"
#import "ExpenseData+Fetch.h"
#import "CategoryData+Fetch.h"
#import "Fetch.h"
    //Data
#import "CategoriesInfo.h"

    //Caategories
#import "NSDate+StartAndEndDatesOfTheCurrentDate.h"
#import "NSDate+FirstAndLastDaysOfMonth.m"
#import "NSDate+IsDateBetweenCurrentMonth.h"
#import "NSDate+IsDatesWithEqualMonth.h"
#import "NSString+FormatAmount.h"

static const CGFloat kMotionEffectMagnitudeValue = 10.0f;

@interface MainViewController () <NSFetchedResultsControllerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *totalAmountLabel;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSFetchedResultsController *todayFetchedResultsController;
@property (nonatomic, strong) NSFetchedResultsController *monthFetchedResultsController;
@property (nonatomic, strong) MainTableViewProtocolsImplementer *tableViewProtocolsImplementer;

@end

@implementation MainViewController {
    CGFloat _totalExpeditures;
    NSMutableArray *_categoriesInfo;

    TitleViewButton *_titleViewButton;
    BOOL _showMonthView;
    NSDate *_dateToShow;
}

#pragma mark - ViewController life cycle -

- (void)viewDidLoad {
    [super viewDidLoad];

    NSParameterAssert(_managedObjectContext);
    NSParameterAssert(self.delegate);

    _dateToShow = [NSDate date];

    self.totalAmountLabel.text = @"";

    self.tableViewProtocolsImplementer = [[MainTableViewProtocolsImplementer alloc]initWithTableView:self.tableView fetchedResultsController:self.todayFetchedResultsController];

    self.todayFetchedResultsController.delegate = _tableViewProtocolsImplementer;
    self.monthFetchedResultsController.delegate = self;

    self.tableView.dataSource = _tableViewProtocolsImplementer;
    self.tableView.delegate   = _tableViewProtocolsImplementer;

    [NSFetchedResultsController deleteCacheWithName:@"todayFetchedResultsController"];
    [NSFetchedResultsController deleteCacheWithName:@"monthFetchedResultsController"];

    [self configurateTitleViewButton];
    [self addMotionEffectToViews];

    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(detailExpenseTableViewControllerDidFinishUpdateExpense:) name:@"DetailExpenseTableViewControllerDidUpdateNotification" object:nil];
}

- (void)dealloc {
    _todayFetchedResultsController.delegate = nil;
    _monthFetchedResultsController.delegate = nil;
}

#pragma mark - Helper methods -

- (void)updateUserInterfaceWithNewFetch:(BOOL)fetch {
    [self loadCategoriesDataBetweenDate:[NSDate date]];
    [self.delegate mainViewController:self didLoadCategoriesInfo:_categoriesInfo];

    if (fetch) {
        [self performFetches];
        [self.tableView reloadData];
    }
    [self updateLabels];
}

- (void)performFetches {
    [self todayPerformFetch];
    [self monthPerformFetch];
}

- (void)loadCategoriesDataBetweenDate:(NSDate *)date {
    _categoriesInfo = [Fetch loadCategoriesInfoInContext:self.managedObjectContext totalExpeditures:& _totalExpeditures andBetweenMonthDate:date];
}

- (void)updateLabels {
    self.totalAmountLabel.text = [NSString formatAmount:@(_totalExpeditures)];
}

- (NSString *)formatDateForMonthLabel:(NSDate *)theDate {
    static NSDateFormatter *formatter = nil;
    if (formatter == nil) {
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"MMMM"];
        if ([[[NSLocale currentLocale]objectForKey:NSLocaleCountryCode]isEqualToString:@"RU"]) {
            [formatter setMonthSymbols:@[@"Январь", @"Февраль", @"Март", @"Апрель", @"Май", @"Июнь", @"Июль", @"Август", @"Сентябрь", @"Октябрь", @"Ноябрь", @"Декабрь"]];
        }
    }
    return [formatter stringFromDate:theDate];
}

- (void)changeMonthToShowFromDate:(NSDate *)date {
    if ([_dateToShow isDatesWithEqualMonth:date]) {
        _titleViewButton.imageView.transform = CGAffineTransformMakeRotation(0);
        return;
    }

    _dateToShow = date;

    [self loadCategoriesDataBetweenDate:_dateToShow];
    [self.delegate mainViewController:self didLoadCategoriesInfo:_categoriesInfo];

    [NSFetchedResultsController deleteCacheWithName:@"todayFetchedResultsController"];
    [NSFetchedResultsController deleteCacheWithName:@"monthFetchedResultsController"];

    NSArray *todayDates = nil;
    NSPredicate *todayPredicate = nil;
    NSArray *monthDates = [_dateToShow getFirstAndLastDaysInTheCurrentMonth];
    NSPredicate *monthPredicate = [ExpenseData compoundPredicateBetweenDates:monthDates];

    if ([NSDate isDateBetweenCurrentMonth:_dateToShow]) {
        todayDates = [NSDate getStartAndEndDatesOfTheCurrentDate];
        todayPredicate = [ExpenseData compoundPredicateBetweenDates:todayDates];
    } else {
        todayDates = [_dateToShow getFirstAndLastDaysInTheCurrentMonth];
        todayPredicate = [ExpenseData compoundPredicateBetweenDates:todayDates];
    }

    self.todayFetchedResultsController.fetchRequest.predicate = todayPredicate;
    self.monthFetchedResultsController.fetchRequest.predicate = monthPredicate;
    [self performFetches];

    [self.tableView reloadData];

    [self updateLabels];

    _titleViewButton = nil;
    [self configurateTitleViewButton];
}

- (NSDate *)dateFromMonthInfo:(NSDictionary *)monthInfo {
    NSCalendar *calendar = [NSCalendar currentCalendar];

    NSDateComponents *dayComponents = [NSDateComponents new];
    dayComponents.year = [monthInfo[@"year"]integerValue];
    dayComponents.month = [monthInfo[@"month"]integerValue];
    dayComponents.day = 10;
    NSDate *date = [calendar dateFromComponents:dayComponents];
    
    return date;
}

- (void)applicationWillResignActive {
    [self changeMonthToShowFromDate:[NSDate date]];
}

#pragma mark - TitleViewButton -

- (void)configurateTitleViewButton {
    _titleViewButton = [TitleViewButton buttonWithType:UIButtonTypeCustom];

    NSString *text = [NSString stringWithFormat:@"%@ ",[self formatDateForMonthLabel:_dateToShow]];
    [_titleViewButton setTitle:text forState:UIControlStateNormal];
    _titleViewButton.titleLabel.font = [UIFont boldSystemFontOfSize:18.0];
    _titleViewButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_titleViewButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];

    _showMonthView = NO;
    UIImage *image = [UIImage imageNamed:@"Down.png"];
    [_titleViewButton setImage:image forState:UIControlStateNormal];
    [_titleViewButton sizeToFit];

    [_titleViewButton addTarget:self action:@selector(titleViewButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.titleView = _titleViewButton;
}

- (void)titleViewButtonPressed:(UIButton *)button {
    _showMonthView = !_showMonthView ? YES : NO;

    if (_showMonthView) {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            _titleViewButton.imageView.transform = CGAffineTransformMakeRotation((CGFloat)180.0 * M_PI/180.0);
        } completion:nil];

        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];

        SelectMonthViewController *selectMonthViewController = [[SelectMonthViewController alloc]initWithNibName:@"SelectMonthViewController" bundle:nil];

        selectMonthViewController.managedObjectContext = self.managedObjectContext;
        selectMonthViewController.delegate = self;

        [selectMonthViewController presentInParentViewController:self.tabBarController];
    }
}

#pragma mark - Segues -

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"AddExpense"]) {
        UINavigationController *navigationController = segue.destinationViewController;

        AddExpenseViewController *controller = (AddExpenseViewController *)navigationController.topViewController;
        controller.delegate = self;
        controller.managedObjectContext = _managedObjectContext;

        NSMutableArray *categoriesTitles = [NSMutableArray arrayWithCapacity:[_categoriesInfo count]];
        for (CategoriesInfo *anInfo in _categoriesInfo) {
            [categoriesTitles addObject:anInfo.title];
        }
        controller.categories = categoriesTitles;

    } else if ([segue.identifier isEqualToString:@"MoreInfo"]) {
        DetailExpenseTableViewController *controller = segue.destinationViewController;
        controller.managedObjectContext = _managedObjectContext;

        if ([sender isKindOfClass:[UITableViewCell class]]) {
            UITableViewCell *cell = (UITableViewCell *)sender;
            NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];

            ExpenseData *expense = [_todayFetchedResultsController objectAtIndexPath:indexPath];
            controller.expenseToShow = expense;
        } else if ([sender isKindOfClass:[ExpenseData class]]) {
            ExpenseData *expense = sender;
            controller.expenseToShow = expense;
        }
    } else if ([segue.identifier isEqualToString:@"CategoriesInfo"]) {
        CategoriesContainerViewController *controller = segue.destinationViewController;
        controller.managedObjectContext = self.managedObjectContext;
        controller.timePeriod = _dateToShow;
        controller.delegate = self;
        
        self.delegate = controller;
    }
}

#pragma mark - Delegate -
#pragma mark AddExpenseViewControllerDelegate

- (void)addExpenseViewController:(AddExpenseViewController *)controller didFinishAddingExpense:(Expense *)expense {
    _totalExpeditures += [expense.amount floatValue];

    [_categoriesInfo enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSParameterAssert([obj isKindOfClass:[CategoriesInfo class]]);
        CategoriesInfo *anInfo = obj;

        if ([anInfo.title isEqualToString:expense.category]) {
            [self updateCategoriesExpensesDataAtIndex:idx withValue:expense.amount.floatValue];

            *stop = YES;
        }

    }];
    [self.delegate mainViewController:self didUpdateCategoriesInfo:_categoriesInfo];
    [self updateLabels];
}

- (void)updateCategoriesExpensesDataAtIndex:(NSInteger)index withValue:(CGFloat)amount {
    CategoriesInfo *info = _categoriesInfo[index];
    CGFloat value = [[info amount] floatValue] + amount;

    info.amount = @(value);
}

#pragma mark AddCategoryViewControllerDelegate

- (void)addCategoryViewController:(AddCategoryViewController *)controller didFinishAddingCategory:(CategoryData *)category {
    CategoriesInfo *info = [[CategoriesInfo alloc]initWithTitle:category.title iconName:category.iconName idValue:category.idValue andAmount:@0];
    [_categoriesInfo addObject:info];
    [self.delegate mainViewController:self didUpdateCategoriesInfo:_categoriesInfo];
}

#pragma mark SelectMonthViewControllerDelegate

- (void)selectMonthViewController:(SelectMonthViewController *)selectMonthViewController didSelectMonth:(NSDictionary *)monthInfo {
    NSDate *date = [self dateFromMonthInfo:monthInfo];

    [self changeMonthToShowFromDate:date];
}

#pragma mark CategoriesContainerViewControllerDelegate

- (void)categoriesContainerViewController:(CategoriesContainerViewController *)controller didChooseCategory:(CategoriesInfo *)category {
    controller.timePeriod = _dateToShow;
}

#pragma mark - DetailExpenseTableViewControllerNotification -

- (void)detailExpenseTableViewControllerDidFinishUpdateExpense:(NSNotification *)notification {
    NSArray *categories = [CategoryData getCategoriesWithExpensesBetweenMonthOfDate:_dateToShow managedObjectContext:_managedObjectContext];

    for (CategoriesInfo *anInfo in _categoriesInfo) {
        anInfo.amount = @0;
    }

    float __block countForExpenditures = 0.0f;

    for (CategoryData *category in categories) {
        [_categoriesInfo enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            CategoriesInfo *anInfo = obj;
            if (category.idValue == anInfo.idValue) {
                anInfo.iconName = category.iconName;

                for (ExpenseData *anExpense in category.expense) {
                    CategoriesInfo *infoForUpdate = _categoriesInfo[idx];
                    infoForUpdate.amount = @([infoForUpdate.amount floatValue] + [anExpense.amount floatValue]);
                    countForExpenditures += [anExpense.amount floatValue];
                }
                *stop = YES;
            }
        }];
        [_managedObjectContext refreshObject:category mergeChanges:NO];
    }
    _totalExpeditures = countForExpenditures;

    [self.delegate mainViewController:self didUpdateCategoriesInfo:_categoriesInfo];
    [self updateLabels];

    [self.tableViewProtocolsImplementer.tableView reloadData];
}

#pragma mark - NSFetchedResultsController -
#pragma mark Today

- (NSFetchedResultsController *)todayFetchedResultsController {
    if (_todayFetchedResultsController) {
        return _todayFetchedResultsController;
    }
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([ExpenseData class])];

        //Create compound predicate: dateOfExpense >= dates[0] AND dateOfExpense <= dates[1]
    NSArray *dates = [NSDate getStartAndEndDatesOfTheCurrentDate];
    NSPredicate *predicate = [ExpenseData compoundPredicateBetweenDates:dates];
    fetchRequest.predicate = predicate;

    NSSortDescriptor *dateSortDescriptor = [[NSSortDescriptor alloc]
                                            initWithKey:NSStringFromSelector(@selector(dateOfExpense)) ascending:NO];
    [fetchRequest setSortDescriptors:@[dateSortDescriptor]];
    [fetchRequest setFetchBatchSize:20];

    NSFetchedResultsController *theFetchedResultsController =
    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                        managedObjectContext:_managedObjectContext
                                          sectionNameKeyPath:nil
                                                   cacheName:@"todayFetchedResultsController"];
    _todayFetchedResultsController = theFetchedResultsController;

    return _todayFetchedResultsController;
}

- (void)todayPerformFetch {
    NSError *todayError;
    if (![self.todayFetchedResultsController performFetch:&todayError]) {
        NSLog(@"Unresolved error %@, %@", todayError, [todayError userInfo]);
        exit(-1);  // Fail
    }
}

#pragma mark Month

- (NSFetchedResultsController *)monthFetchedResultsController {
    if (_monthFetchedResultsController) {
        return _monthFetchedResultsController;
    }
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([ExpenseData class])];

        //Create compound predicate: dateOfExpense >= dates[0] AND dateOfExpense <= dates[1]
    NSArray *dates = [NSDate getFirstAndLastDaysInTheCurrentMonth];
    NSPredicate *predicate = [ExpenseData compoundPredicateBetweenDates:dates];
    fetchRequest.predicate = predicate;

    NSSortDescriptor *dateSortDescriptor = [[NSSortDescriptor alloc]
                                            initWithKey:NSStringFromSelector(@selector(dateOfExpense)) ascending:NO];
    [fetchRequest setSortDescriptors:@[dateSortDescriptor]];
    [fetchRequest setFetchBatchSize:20];

    NSFetchedResultsController *theFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:_managedObjectContext sectionNameKeyPath:nil
                                                   cacheName:@"monthFetchedResultsController"];
    _monthFetchedResultsController = theFetchedResultsController;

    return _monthFetchedResultsController;
}

- (void)monthPerformFetch {
    NSError *monthError;
    if (![self.monthFetchedResultsController performFetch:&monthError]) {
        NSLog(@"Unresolved error %@, %@", monthError, [monthError userInfo]);
        exit(-1);  // Fail
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    switch(type) {
        case NSFetchedResultsChangeInsert:
        case NSFetchedResultsChangeUpdate:
        case NSFetchedResultsChangeMove:
            break;

        case NSFetchedResultsChangeDelete: {
            ExpenseData *deletedExpense = (ExpenseData *)anObject;
            _totalExpeditures -= [deletedExpense.amount floatValue];

            [_categoriesInfo enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                CategoriesInfo *info = obj;
                if (info.idValue == deletedExpense.categoryId) {
                    [self updateCategoriesExpensesDataAtIndex:idx withValue:-deletedExpense.amount.floatValue];

                    *stop = YES;
                }
            }];
            [self.delegate mainViewController:self didUpdateCategoriesInfo:_categoriesInfo];
            [self updateLabels];
            return;
        }
    }
}

#pragma mark - MotionEffect -

- (void)addMotionEffectToViews {
    for (UIView *aView in self.view.subviews) {
        if ([aView isKindOfClass:[UITableView class]]) {
            [self makeLargerFrameForView:aView withValue:kMotionEffectMagnitudeValue];
            [self addMotionEffectToView:aView magnitude:kMotionEffectMagnitudeValue];
        }
    }
}

- (void)makeLargerFrameForView:(UIView *)view withValue:(CGFloat)value {
    view.frame = CGRectInset(view.frame, -value, -value);
}

- (void)addMotionEffectToView:(UIView *)view magnitude:(CGFloat)magnitude {
    UIInterpolatingMotionEffect *xMotion = [[UIInterpolatingMotionEffect alloc]
                                            initWithKeyPath:@"center.x"
                                            type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    xMotion.minimumRelativeValue = @(-magnitude);
    xMotion.maximumRelativeValue = @(magnitude);

    UIInterpolatingMotionEffect *yMotion = [[UIInterpolatingMotionEffect alloc]
                                            initWithKeyPath:@"center.y"
                                            type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    yMotion.minimumRelativeValue = @(-magnitude);
    yMotion.maximumRelativeValue = @(magnitude);

    UIMotionEffectGroup *group = [UIMotionEffectGroup new];
    group.motionEffects = @[xMotion, yMotion];
    [view addMotionEffect:group];
}

@end