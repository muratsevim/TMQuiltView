//
//  TMQuiltView.m
//  TMQuiltView
//
//  Created by Bruno Virlet on 7/20/12.
//
//  Copyright (c) 2012 1000memories

//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO 
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR 
//  THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "TMQuiltView.h"
#import "TMQuiltViewCell.h"

const NSInteger kTMQuiltViewDefaultColumns = 2;
const CGFloat kTMQuiltViewDefaultMargin = 10.0f;
const CGFloat kTMQuiltViewDefaultCellHeight = 50.0f;

NSString *const kDefaultReusableIdentifier = @"kTMQuiltViewDefaultReusableIdentifier";

@interface TMQuiltView(){
      BOOL _videoPlayedInFullScreen;
}

@property (nonatomic, readonly, retain) NSMutableSet *indexPaths;
@property (nonatomic, readonly, retain) NSMutableDictionary *reusableViewsDictionary;

@property (nonatomic, assign) NSInteger numberOfColumns;

@property (nonatomic, readonly) NSMutableArray **indexPathsByColumn;
@property (nonatomic, readonly) NSMutableArray **cellTopByColumn;
@property (nonatomic, readonly) int *topByColumn;
@property (nonatomic, readonly) int *bottomByColumn;
@property (nonatomic, readonly) NSMutableDictionary **indexPathToViewByColumn;

@property (nonatomic, retain) NSMutableSet *rowsToInsert;
@property (nonatomic, retain) NSMutableSet *rowsToDelete;

@property (nonatomic, readonly) UITapGestureRecognizer *tapGestureRecognizer;


+ (BOOL) isRect:(CGRect)rect entirelyInOrAboveScrollView:(UIScrollView *)scrollView;
+ (BOOL) isRect:(CGRect)rect entirelyInOrBelowScrollView:(UIScrollView *)scrollView;
+ (BOOL) isRect:(CGRect)rect partiallyInScrollView:(UIScrollView *)scrollView;

- (void) resetView;

@end

@implementation TMQuiltView

@synthesize dataSource = _dataSource;

@synthesize indexPaths = _indexPaths;
@synthesize reusableViewsDictionary = _reusableViewsDictionary;

@synthesize numberOfColumns = _numberOfColumns;

@synthesize indexPathsByColumn = _indexPathsByColumn;
@synthesize cellTopByColumn = _cellTopByColumn;
@synthesize topByColumn = _topByColumn;
@synthesize bottomByColumn = _bottomByColumn;
@synthesize indexPathToViewByColumn = _indexPathToViewByColumn;

@synthesize rowsToDelete = _rowsToDelete;
@synthesize rowsToInsert = _rowsToInsert;

@synthesize tapGestureRecognizer = _tapGestureRecognizer;

#pragma mark - Memory Management

- (void)dealloc {
    [_indexPaths release], _indexPaths = nil;
    [_reusableViewsDictionary release], _reusableViewsDictionary = nil;
    [_rowsToInsert release], _rowsToInsert = nil;
    [_rowsToDelete release], _rowsToDelete = nil;
    
    [self cleanupColumns];
    
    [self removeGestureRecognizer:self.tapGestureRecognizer];
    [_tapGestureRecognizer release], _tapGestureRecognizer = nil;
    
    [super dealloc];
}

- (void)cleanupColumns {
    [self recycleViews];
    for (int i = 0; i < _numberOfColumns; i++) {
        [self.indexPathsByColumn[i] release], self.indexPathsByColumn[i] = nil;
        [self.cellTopByColumn[i] release], self.cellTopByColumn[i] = nil;
        [self.indexPathToViewByColumn[i] release], self.indexPathToViewByColumn[i] = nil;
    }
    free(_indexPathsByColumn), _indexPathsByColumn = nil;
    free(_cellTopByColumn), _cellTopByColumn = nil;
    free(_indexPathToViewByColumn), _indexPathToViewByColumn = nil;
    
    free(_topByColumn), _topByColumn = nil;
    free(_bottomByColumn), _bottomByColumn = nil;
}

- (void)recycleViews {
    for (int i = 0; i < _numberOfColumns; i++) {
        self.topByColumn[i] = -1;
        self.bottomByColumn[i] = -1;
        for (NSIndexPath *indexPath in [self.indexPathToViewByColumn[i] allKeys]) { 
            TMQuiltViewCell *view = [self.indexPathToViewByColumn[i] objectForKey:indexPath];
            [self.indexPathToViewByColumn[i] removeObjectForKey:indexPath];
            [[self reusableViewsWithReuseIdentifier:view.reuseIdentifier] addObject:view];
            [view removeFromSuperview];
        }
    }
}

#pragma mark - Initialization

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        super.alwaysBounceVertical = YES;
        [self addGestureRecognizer:self.tapGestureRecognizer];
        _numberOfColumns = kTMQuiltViewDefaultColumns;
        _videoPlayedInFullScreen = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoInFullScreenDidStart:) name:@"UIMoviePlayerControllerDidEnterFullscreenNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoInFullScreenDidEnd:) name:@"UIMoviePlayerControllerDidExitFullscreenNotification" object:nil];
    }
    return self;
}
 
- (void)videoInFullScreenDidStart:(id)notification
{
    _videoPlayedInFullScreen = YES;
}

- (void)videoInFullScreenDidEnd:(id)notification
{
    _videoPlayedInFullScreen = NO;
}


- (void)setDelegate:(id<TMQuiltViewDelegate>)delegate {
    [super setDelegate:delegate];
}

- (id)delegate {
    return [super delegate];
}

#pragma mark - Data Structures

- (NSMutableSet *)indexPaths {
    if (!_indexPaths) {
        _indexPaths = [[NSMutableSet alloc] init];
    }
    return _indexPaths;
}

- (NSMutableSet *)reusableViewsWithReuseIdentifier:(NSString *)reuseIdentifier {
    if (!_reusableViewsDictionary) {
        _reusableViewsDictionary = [[NSMutableDictionary alloc] init];
    }
    if (!reuseIdentifier) {
        reuseIdentifier = kDefaultReusableIdentifier;
    }
    NSMutableSet *reusableViews = [_reusableViewsDictionary objectForKey:reuseIdentifier];
    if (!reusableViews) {
        reusableViews = [[[NSMutableSet alloc] init] autorelease];
        [_reusableViewsDictionary setObject:reusableViews forKey:reuseIdentifier];
    }
    return reusableViews;
}

- (NSMutableArray **)indexPathsByColumn {
    if (!_indexPathsByColumn) {
        _indexPathsByColumn = malloc(sizeof(NSMutableArray*) * _numberOfColumns);
        for (int i = 0; i < _numberOfColumns; i++) {
            _indexPathsByColumn[i] = [[NSMutableArray alloc] init];
        }
    }
    return _indexPathsByColumn;
}

- (NSMutableArray **)cellTopByColumn {
    if (!_cellTopByColumn) {
        _cellTopByColumn = malloc(sizeof(NSMutableArray*) * _numberOfColumns);
        for (int i = 0; i < _numberOfColumns; i++) {
            _cellTopByColumn[i] = [[NSMutableArray alloc] init];
        }
    }
    return _cellTopByColumn;
}

- (NSMutableDictionary **)indexPathToViewByColumn {
    if (!_indexPathToViewByColumn) {
        _indexPathToViewByColumn = malloc(sizeof(NSMutableSet*) * _numberOfColumns);
        for (int i = 0; i < _numberOfColumns; i++) {
            _indexPathToViewByColumn[i] = [[NSMutableDictionary alloc] init];
        }
    }
    return _indexPathToViewByColumn;
}

- (int *)topByColumn {
    if (!_topByColumn) {
        _topByColumn = malloc(sizeof(int) * _numberOfColumns);
    }
    return _topByColumn;
}

- (int *)bottomByColumn {
    if (!_bottomByColumn) {
        _bottomByColumn = malloc(sizeof(int) * _numberOfColumns);
    }
    return _bottomByColumn;
}

- (NSInteger)numberOfCells {
    return [self.dataSource quiltViewNumberOfCells:self];
}

- (NSInteger)numberOfCellsInColumn:(NSInteger)column {
    return [self.indexPathsByColumn[column] count];
}

- (NSUInteger)numberOfColumnsAccordingToDelegate{
  if ([self.delegate respondsToSelector:@selector(quiltViewNumberOfColumns:)]) {
    return [self.delegate quiltViewNumberOfColumns:self];
  } else {
    return kTMQuiltViewDefaultColumns;
  }
}

- (void)updateNumberOfColumns{
  _numberOfColumns = [self numberOfColumnsAccordingToDelegate];
}

- (void)reloadDataIfNumberOfColumnsHasChanged{
  if (_numberOfColumns != [self numberOfColumnsAccordingToDelegate]) {
    [self reloadData];
  }
}

/**
 Excerpt from UITableView doc:
 
 Return Value:
 An object representing a cell of the table or nil if the cell is not visible or indexPath is out of range.
 */
- (TMQuiltViewCell *)cellAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= [self numberOfCells]) {
        return nil;
    }
    for(int i = 0; i < _numberOfColumns; i++) {
        TMQuiltViewCell *cell = [self.indexPathToViewByColumn[i] objectForKey:indexPath];
        if (cell) {
            return cell;
        }
    }
    return nil;
}

- (TMQuiltViewCell *)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier {
    TMQuiltViewCell *view = [[self reusableViewsWithReuseIdentifier:identifier] anyObject];
    if (view) {
        [view retain];
        view.selected = NO;
        [[self reusableViewsWithReuseIdentifier:identifier] removeObject:view];
    }
    
    return [view autorelease];
}

#pragma mark - Cell creation, insertion and deletion

- (void)beginUpdates {
    self.rowsToDelete = [NSMutableSet set];
    self.rowsToInsert = [NSMutableSet set];
}

- (void)insertCellAtIndexPath:(NSIndexPath *)insertedIndexPath {
    [self.rowsToInsert addObject:insertedIndexPath];
}

- (void)deleteCellAtIndexPath:(NSIndexPath *)deletedIndexPath {
    [self.rowsToDelete addObject:deletedIndexPath];

}

- (void)moveCellAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath {
    [self.rowsToDelete addObject:indexPath];
    [self.rowsToInsert addObject:newIndexPath];
}

- (void)endUpdates {
    [self resetView];
}

#pragma mark - Cell organization

// Regenerates the index paths based on the number of rows
- (void)regenerateIndexPaths {
    [self.indexPaths removeAllObjects];
	
    NSInteger numberOfRows = [self numberOfCells];
    for(NSInteger i = 0; i < numberOfRows; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        [self.indexPaths addObject:indexPath];
        [self cellAtIndexPath:indexPath];
    }
}

- (void)reloadData {
    [self cleanupColumns];
    [self updateNumberOfColumns];
  
    [self regenerateIndexPaths];
    [self resetView];
}

// Move all the view into the recycle pool and render the topmost cells
- (void)resetView {
    
    [self regenerateIndexPaths];
    
    self.rowsToDelete = nil;
    self.rowsToInsert = nil;
    
    // -----
    
    float heights[_numberOfColumns];
    for (int i = 0; i < _numberOfColumns; i++) {
        heights[i] = 0.0;
    }
    
    for (int i = 0; i < _numberOfColumns; i++) {
        [self.indexPathsByColumn[i] removeAllObjects];
        [self.cellTopByColumn[i] removeAllObjects];
    }
    
    // Calculate every cells rect, as well as the total height for the quilt
    for (NSIndexPath *indexPath in [[self.indexPaths allObjects] sortedArrayUsingSelector:@selector(compare:)]) {
        int shortestColumn = 0;
        int shortestHeight = heights[0];
        
        for (int i = 1; i < _numberOfColumns; i++) {
            if (heights[i] < shortestHeight) {
                shortestColumn = i;
                shortestHeight = heights[i];
            }
        }
        
        float height = [self heightForCellAtIndexPath:indexPath];
        CGFloat cellTop = shortestHeight + [self cellMargin:TMQuiltViewCellMarginTop];
        
        [self.indexPathsByColumn[shortestColumn] addObject:indexPath];
        [self.cellTopByColumn[shortestColumn] addObject:[NSNumber numberWithInt:cellTop]];
        
        heights[shortestColumn] += height + [self cellMargin:TMQuiltViewCellMarginRows];
    }
    
    int tallestHeight = heights[0];
    
    for (int i = 1; i < _numberOfColumns; i++) {
        if (heights[i] > tallestHeight) {
            tallestHeight = heights[i];
        }
    }
    
    self.contentSize = CGSizeMake(self.bounds.size.width, tallestHeight + [self cellMargin:TMQuiltViewCellMarginBottom]);

    //
    [self recycleViews];
    
    [self setNeedsLayout];
}

#pragma mark - Layout

- (CGFloat)heightForCellAtIndexPath:(NSIndexPath *)indexPath {
    
    if ([self.delegate respondsToSelector:@selector(quiltView:heightForCellAtIndexPath:)]) {
        return [self.delegate quiltView:self heightForCellAtIndexPath:indexPath];
    }
    
    return kTMQuiltViewDefaultCellHeight;
}

- (CGFloat)cellMargin:(TMQuiltViewMarginType)marginType {
    if ([self.delegate respondsToSelector:@selector(quiltViewMargin:marginType:)]) {
        return [self.delegate quiltViewMargin:self marginType:marginType];
    }
    return kTMQuiltViewDefaultMargin;
}

- (CGFloat)cellWidth {
    CGFloat cellWidth = (self.bounds.size.width 
                         - [self cellMargin:TMQuiltViewCellMarginLeft] 
                         - [self cellMargin:TMQuiltViewCellMarginColumns] * (_numberOfColumns - 1)
                         - [self cellMargin:TMQuiltViewCellMarginRight]
                         ) / _numberOfColumns;
    return cellWidth;
}

- (CGRect)rectForCellAtIndex:(int)index column:(int)column {
    
    NSInteger cellTop = [[self.cellTopByColumn[column] objectAtIndex:index] floatValue];
    float height = [self heightForCellAtIndexPath:[self.indexPathsByColumn[column] objectAtIndex:index]];

    return CGRectMake(column * ([self cellWidth] + [self cellMargin:TMQuiltViewCellMarginColumns]) + [self cellMargin:TMQuiltViewCellMarginLeft],
                             cellTop,
                             [self cellWidth], height);
}

- (void)layoutSubviews {    
    [super layoutSubviews];
    
    self.contentSize = CGSizeMake(self.bounds.size.width, self.contentSize.height);
    
    for (int i = 0; i < _numberOfColumns; i++) {
        NSArray *indexPaths = self.indexPathsByColumn[i];
        NSMutableDictionary *indexPathToView = self.indexPathToViewByColumn[i];
        int *top = &self.topByColumn[i];
        int *bottom = &self.bottomByColumn[i];
        
        // Skip this column if it has no cells
        if ([indexPaths count] == 0) {
            continue;
        }
        
        // Create the top cells if they don't exist yet.
        if (*top == -1 && *bottom == -1) {
            if ([self.indexPathsByColumn[i] count] > 0) {
                NSIndexPath* indexPath = [self.indexPathsByColumn[i] objectAtIndex:0];
            
                TMQuiltViewCell *newCell = [self.dataSource quiltView:self cellAtIndexPath:indexPath];
                newCell.frame = [self rectForCellAtIndex:0 column:i];
                [self.indexPathToViewByColumn[i] setObject:newCell forKey:indexPath];
                [self addSubview:newCell];
                [[self reusableViewsWithReuseIdentifier:newCell.reuseIdentifier] removeObject:newCell];
                *top = 0;
                *bottom = 0;
            } else {
                break;
            }
        }
        
        
        
        for(int j = *top; j <= *bottom; j++) {
            TMQuiltViewCell *visibleCell = (TMQuiltViewCell *)[indexPathToView objectForKey:[indexPaths objectAtIndex:j]];
            visibleCell.frame = [self rectForCellAtIndex:j column:i];
        }
        
        // Add a new cell to the bottom if our bottom cell is above the bottom of the visible area (and not the last cell)
        while ((*bottom < [indexPaths count] - 1) && [TMQuiltView isRect:[self rectForCellAtIndex:*bottom column:i] entirelyInOrAboveScrollView:self]) {
            
            if ([TMQuiltView isRect:[self rectForCellAtIndex:*bottom + 1 column:i] partiallyInScrollView:self]) {
                NSIndexPath *newIndexPath = [indexPaths objectAtIndex:*bottom + 1];
                UIView* newCell = [self.dataSource quiltView:self cellAtIndexPath:newIndexPath];
                [self addSubview:newCell];
                newCell.frame = [self rectForCellAtIndex:*bottom + 1 column:i];
                [indexPathToView setObject:newCell forKey:newIndexPath];
            }
            (*bottom)++;
        }

        // Add a new cell to the top if our top cell is below the top of the visible area (and not the first cell)
        while ((*top > 0) && [TMQuiltView isRect:[self rectForCellAtIndex:*top column:i] entirelyInOrBelowScrollView:self]) {
            if ([TMQuiltView isRect:[self rectForCellAtIndex:*top - 1 column:i] partiallyInScrollView:self]) {
                NSIndexPath *newIndexPath = [indexPaths objectAtIndex:*top - 1];
                TMQuiltViewCell* newCell = [self.dataSource quiltView:self cellAtIndexPath:newIndexPath];
                newCell.frame = [self rectForCellAtIndex:*top - 1 column:i];
                [indexPathToView setObject:newCell forKey:newIndexPath];
                [self addSubview:newCell];
            }
            (*top)--;
        }
        
        // Harvest any any views that have moved off screen and add them to the reuse pool
        for (NSIndexPath* indexPath in [indexPathToView allKeys]) {
            TMQuiltViewCell *view = [indexPathToView objectForKey:indexPath];

            if (![TMQuiltView isRect:view.frame partiallyInScrollView:self]) { // Rect intersection?
                [indexPathToView removeObjectForKey:indexPath];
                
                // Limit the size on the reuse pool
                if ([[self reusableViewsWithReuseIdentifier:view.reuseIdentifier] count] < 10) {
                    [[self reusableViewsWithReuseIdentifier:view.reuseIdentifier] addObject:view];
                }
                
                [view removeFromSuperview];
                // Only harvest once per call to make things smoother
                //break;
            }
        }
        
        // Move top and bottom if the cells they point to were harvested
        for (int j = 0; j < [indexPaths count]; j++) {
            if ([indexPathToView objectForKey:[indexPaths objectAtIndex:j]] != nil) {
                *top = j;
                break;
            }
        }
        
        for (int j = (int)[indexPaths count] - 1; j >= 0; j--) {
            if ([indexPathToView objectForKey:[indexPaths objectAtIndex:j]] != nil) {
                *bottom = j;
                break;
            }
        }

        // The last cell in a column might have been harvested after our scroll view bounce.
        // Here we check if the last cell's frame is partially in our scroll view
        if (*bottom == [indexPaths count] - 1 && [TMQuiltView isRect:[self rectForCellAtIndex:*bottom column:i] partiallyInScrollView:self]){
            NSIndexPath *indexPath = [indexPaths objectAtIndex:*bottom];
            // We check, if the last cell has actually been harvested...
            if ([indexPathToView objectForKey:indexPath] == nil) {
                // ... and if so, we add it back
                UIView* cell = [self.dataSource quiltView:self cellAtIndexPath:indexPath];
                [self addSubview:cell];
                [indexPathToView setObject:cell forKey:indexPath];
            }
        }
    }
}

- (void)setFrame:(CGRect)frame {
  // If we have an MPMoviePlayer that is just exiting fullscreen,
  // removing it's superview from the view hierarchy would cause
  // the minimalize animation to be broken
  if (_videoPlayedInFullScreen) {
    _videoPlayedInFullScreen = NO;
    return;
  }

  CGRect oldFrame = self.frame;
  [super setFrame:frame];
  if (!CGSizeEqualToSize(oldFrame.size, frame.size)) {
    // We need to recompute the cell tops because their width is
    // based on the bounding width, and their height is generally based
    // on their width.
    [self resetView];
  }
}

#pragma mark - Cell visibility

- (NSArray *)visibleCells {
    NSMutableArray *visibleCells = [NSMutableArray arrayWithCapacity:[self.indexPaths count]];
    
    for(NSIndexPath *indexPath in self.indexPaths) {
        TMQuiltViewCell *cell = [self cellAtIndexPath:indexPath];
        if (cell) {
            [visibleCells addObject:cell];
        }
    }
    
    return visibleCells;
}

+ (BOOL)isRect:(CGRect)rect entirelyInOrAboveScrollView:(UIScrollView *)scrollView {
    int scrollViewBottom = scrollView.contentOffset.y + scrollView.bounds.size.height;
    int rectBottom = rect.origin.y + rect.size.height;
    
    return (rectBottom < scrollViewBottom) ? YES : NO;
}

+ (BOOL)isRect:(CGRect)rect entirelyInOrBelowScrollView:(UIScrollView *)scrollView {
    int scrollViewTop = scrollView.contentOffset.y;
    int rectTop = rect.origin.y;
    
    return (rectTop > scrollViewTop) ? YES : NO;
}

+ (BOOL)isRect:(CGRect)rect partiallyInScrollView:(UIScrollView *)scrollView {
    int scrollViewTop = scrollView.contentOffset.y;
    int scrollViewBottom = scrollViewTop + scrollView.bounds.size.height;
    int rectTop = rect.origin.y;
    int rectBottom = rectTop + rect.size.height;
    
    return (rectTop > scrollViewBottom || rectBottom < scrollViewTop) ? NO : YES;
}

#pragma mark - tap on cells

- (UITapGestureRecognizer *)tapGestureRecognizer {
    if (!_tapGestureRecognizer) {
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped:)];
        _tapGestureRecognizer.delegate = self;
    }
    return _tapGestureRecognizer;
}

- (void)viewTapped:(UIGestureRecognizer *)recognizer {
    
    if ([recognizer state] != UIGestureRecognizerStateEnded) {
        return;
    }
    
    CGPoint tapPoint = [recognizer locationInView:self];        
    
    for(int i = 0; i < _numberOfColumns; i++) {
        NSEnumerator *displayedViewEnumerator = [self.indexPathToViewByColumn[i] keyEnumerator];
        NSIndexPath *indexPath = nil;
        while((indexPath = (NSIndexPath *)[displayedViewEnumerator nextObject])) {
            TMQuiltViewCell *photoCell = [self.indexPathToViewByColumn[i] objectForKey:indexPath];
            if (CGRectContainsPoint(photoCell.frame, tapPoint)) {
                photoCell.selected = YES;
                if ([self.delegate respondsToSelector:@selector(quiltView:didSelectCellAtIndexPath:)]) {
                    [self.delegate quiltView:self didSelectCellAtIndexPath:indexPath];
                }
                return;
            }
        }
    }
    
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[UIControl class]]) {
        // we touched a button, slider, or other UIControl
        return NO; // ignore the touch
    }
    return YES; // handle the touch
}


@end
