//
//  MTProgramList.m
//  myTivo
//
//  Created by Scott Buchanan on 12/7/12.
//  Copyright (c) 2012 Scott Buchanan. All rights reserved.
//

#import "MTProgramTableView.h"
#import "MTDownloadCheckTableCell.h"
#import "MTTiVoManager.h"


@implementation MTProgramTableView
@synthesize  sortedShows= _sortedShows;

-(id) initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self setNotifications];
	}
	return self;
}

-(void)setNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadEpisode:) name:kMTNotificationDetailsLoaded object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:kMTNotificationTiVoShowsUpdated  object:nil];
	
}

-(void)awakeFromNib
{
    self.dataSource = self;
    self.delegate    = self;
    self.allowsMultipleSelection = YES;
	self.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    self.selectedTiVo = [[NSUserDefaults standardUserDefaults] objectForKey:kMTSelectedTiVo];
    tiVoColumnHolder = [[self tableColumnWithIdentifier:@"TiVo"] retain];
}

-(void)reloadData
{
    //Configure Table Columns depending on how many TiVos
    NSTableColumn *tiVoColumn = [self tableColumnWithIdentifier:@"TiVo"];
    NSTableColumn *programColumn = [self tableColumnWithIdentifier:@"Programs"];
    BOOL changedColumns = NO;
    if (tiVoManager.tiVoList.count == 1) {
        if (tiVoColumn) {
            [self removeTableColumn:tiVoColumn];
            programColumn.width += tiVoColumn.width + 3;
            changedColumns = YES;
        }
    } else {
        if (!tiVoColumn) {
            [self addTableColumn:tiVoColumnHolder];
            NSInteger colPos = [self columnWithIdentifier:@"TiVo"];
            [self moveColumn:colPos toColumn:1];
            programColumn.width -= tiVoColumn.width + 3;
            changedColumns = YES;
        }
    }
    if (changedColumns) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationDownloadQueueUpdated object:nil];
    }
    NSIndexSet * selectedRowIndexes = [self selectedRowIndexes];
    
    NSArray * selectedItems = [self.sortedShows objectsAtIndexes:selectedRowIndexes];
    self.sortedShows = nil;
    [super reloadData];
    
    NSMutableIndexSet * newSelectionIndexes = [[[NSMutableIndexSet alloc] init] autorelease] ;
    for (MTTiVoShow * show in selectedItems) {
        NSUInteger index = [self.sortedShows indexOfObject:show];
        if (index != NSNotFound) {
            [newSelectionIndexes addIndex:index];
        }
    }
    [self selectRowIndexes:newSelectionIndexes byExtendingSelection:NO];
    
}

-(void)reloadEpisode:(NSNotification *)notification
{
	MTTiVoShow *thisShow = notification.object;
	NSInteger row = 0;
	NSArray *displayedShows = self.sortedShows;
	for (row=0; row < displayedShows.count; row++) {
		if ([displayedShows objectAtIndex:row] == thisShow) {
			break;
		}
	}
	NSInteger column = [self columnWithIdentifier:@"Episode"];
	[self reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:column]];
}


-(void)dealloc
{
    [tiVoColumnHolder release];
    self.selectedTiVo = nil;
    self.sortedShows = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

#pragma mark - Table Delegate Protocol

-(IBAction)selectTivo:(id)sender
{
    if (tiVoManager.tiVoList.count > 1) { //Nothing to change otherwise
        self.selectedTiVo = [(NSPopUpButton *)sender selectedItem].title;
        [[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationTiVoListUpdated object:_selectedTiVo];
		[[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationTiVoShowsUpdated object:nil];
        [[NSUserDefaults standardUserDefaults] setObject:self.selectedTiVo forKey:kMTSelectedTiVo];
    }
    
}

-(NSArray *)sortedShows
{
    if (!_sortedShows ) {
        NSMutableArray *arrayToSort = [NSMutableArray arrayWithArray:tiVoManager.tiVoShows];
        NSPredicate *tiVoPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            return YES;
        }];;
        if (self.selectedTiVo && [self.selectedTiVo compare:kMTAllTiVos] != NSOrderedSame) { //We need a predicate for filtering
            tiVoPredicate = [NSPredicate predicateWithFormat:@"tiVo.tiVo.name == %@",self.selectedTiVo];
        }
        [arrayToSort filterUsingPredicate:tiVoPredicate];
        self.sortedShows = [arrayToSort  sortedArrayUsingDescriptors:self.sortDescriptors];
    }
    return _sortedShows;
}


#pragma mark - Table Data Source Protocol

-(void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    [self reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return self.sortedShows.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    // get an existing cell with the MyView identifier if it exists
    NSTableCellView *result = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    MTTiVoShow *thisShow = [self.sortedShows objectAtIndex:row];
    // There is no existing cell to reuse so we will create a new one
    if (result == nil) {
        
        // create the new NSTextField with a frame of the {0,0} with the width of the table
        // note that the height of the frame is not really relevant, the row-height will modify the height
        // the new text field is then returned as an autoreleased object
        result = [[[NSTableCellView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 20)] autorelease];
        //        result.textField.font = [NSFont userFontOfSize:14];
        result.textField.editable = NO;
        
        // the identifier of the NSTextField instance is set to MyView. This
        // allows it to be re-used
        result.identifier = tableColumn.identifier;
    }
    
    // result is now guaranteed to be valid, either as a re-used cell
    // or as a new cell, so set the stringValue of the cell to the
    // nameArray value at row
	if ([tableColumn.identifier compare:@"Programs"] == NSOrderedSame) {
		result.textField.stringValue = thisShow.showTitle ;
        result.toolTip = result.textField.stringValue;
	} else if ([tableColumn.identifier compare:@"TiVo"] == NSOrderedSame) {
        result.textField.stringValue = thisShow.tiVo.tiVo.name;
        result.toolTip = thisShow.tiVo.tiVo.name;
    } else if ([tableColumn.identifier compare:@"Date"] == NSOrderedSame) {
		result.textField.stringValue = thisShow.showDateString;
		[result.textField setAlignment:NSCenterTextAlignment];
        result.toolTip = result.textField.stringValue;
	} else if ([tableColumn.identifier compare:@"Length"] == NSOrderedSame) {
		result.textField.stringValue = [NSString stringWithFormat:@"%ld:%0.2ld",thisShow.showLength/60,thisShow.showLength % 60];
		[result.textField setAlignment:NSCenterTextAlignment];
        result.toolTip = result.textField.stringValue;
	} else if ([tableColumn.identifier compare:@"Episode"] == NSOrderedSame) {
		result.textField.stringValue = thisShow.seasonEpisode;
		[result.textField setAlignment:NSCenterTextAlignment];
        result.toolTip = result.textField.stringValue;
	} else if ([tableColumn.identifier compare:@"Queued"] == NSOrderedSame) {
        if (thisShow.isQueued) {
            result.textField.stringValue = @"✔";
        } else {
            result.textField.stringValue = @"";
        }
	}

    // return the result.
    return result;
    
}

@end