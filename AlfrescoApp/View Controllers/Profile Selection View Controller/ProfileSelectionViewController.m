/*******************************************************************************
 * Copyright (C) 2005-2015 Alfresco Software Limited.
 *
 * This file is part of the Alfresco Mobile iOS App.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ******************************************************************************/

#import "ProfileSelectionViewController.h"
#import "AlfrescoConfigService.h"
#import "AppConfigurationManager.h"
#import "UserAccount.h"

static NSString * const kProfileCellIdentifier = @"ProfileCellIdentifier";

@interface ProfileSelectionViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSArray *tableViewData;
@property (nonatomic, strong) NSString *originallySelectedProfileIdentifier;
@property (nonatomic, strong) AlfrescoProfileConfig *currentlySelectedProfile;
@property (nonatomic, strong) AlfrescoConfigService *configService;
@property (nonatomic, strong) UserAccount *account;
@property (nonatomic, strong) id<AlfrescoSession> session;
@end

@implementation ProfileSelectionViewController

- (instancetype)initWithAccount:(UserAccount *)account session:(id<AlfrescoSession>)session
{
    self = [super init];
    if (self)
    {
        self.account = account;
        self.session = session;
        self.configService = [[AppConfigurationManager sharedManager] configurationServiceForAccount:account];
        self.originallySelectedProfileIdentifier = account.selectedProfileIdentifier;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"main.menu.profile.selection.title", @"Profile Title");
    
    [self loadData];
}

- (void)dealloc
{
    if (![self.originallySelectedProfileIdentifier isEqualToString:self.currentlySelectedProfile.identifier])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kAlfrescoConfigurationProfileDidChangeNotification
                                                            object:self.currentlySelectedProfile
                                                          userInfo:@{kAlfrescoConfigurationProfileDidChangeForAccountKey : self.account}];
    }
}

#pragma mark - Private Methods

- (void)loadData
{
    [self.configService clear];
    if ((self.configService == [[AppConfigurationManager sharedManager] configurationServiceForCurrentAccount]) && (!self.configService.session))
    {
        self.configService.session = self.session;
    }
    [self.configService retrieveProfilesWithCompletionBlock:^(NSArray *profilesArray, NSError *profilesError) {
        if (profilesError)
        {
            [[AppConfigurationManager sharedManager] removeConfigurationFileForAccount:self.account];
            self.configService = [[AppConfigurationManager sharedManager] configurationServiceForAccount:self.account];
            [self.configService retrieveDefaultProfileWithCompletionBlock:^(AlfrescoProfileConfig *config, NSError *error) {
                self.tableViewData = [NSArray arrayWithObject:config];
                [self.tableView reloadData];
                [self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            }];
        }
        else
        {
            self.tableViewData = profilesArray;
            [self.tableView reloadData];
            BOOL shouldAutoSelectProfile = YES;
            for (int i = 0; i < self.tableViewData.count; i++)
            {
                AlfrescoProfileConfig *profile = self.tableViewData[i];
                if([self.originallySelectedProfileIdentifier isEqualToString:profile.identifier])
                {
                    shouldAutoSelectProfile = NO;
                }
            }
            
            if(shouldAutoSelectProfile)
            {
                [self.configService retrieveDefaultProfileWithCompletionBlock:^(AlfrescoProfileConfig *config, NSError *error) {
                    for (int i = 0; i < self.tableViewData.count; i++)
                    {
                        AlfrescoProfileConfig *profile = self.tableViewData[i];
                        if([config.identifier isEqualToString:profile.identifier])
                        {
                            [self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
                        }
                    }
                    
                }];
            }
        }
    }];
}

#pragma mark - UITableViewDataSource Delegate Methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.tableViewData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kProfileCellIdentifier];
    
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kProfileCellIdentifier];
    }
    
    AlfrescoProfileConfig *currentProfile = self.tableViewData[indexPath.row];
    cell.textLabel.text = NSLocalizedString(currentProfile.label, @"Localised Label");
    cell.detailTextLabel.text = NSLocalizedString(currentProfile.summary, @"Localised Summary");
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if ([currentProfile.identifier isEqualToString:self.originallySelectedProfileIdentifier])
    {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        self.currentlySelectedProfile = currentProfile;
    }
    else
    {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *deselectedCell = [tableView cellForRowAtIndexPath:indexPath];
    deselectedCell.accessoryType = UITableViewCellAccessoryNone;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath:indexPath];
    selectedCell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    AlfrescoProfileConfig *selectedProfile = self.tableViewData[indexPath.row];
    self.currentlySelectedProfile = selectedProfile;
}

@end
