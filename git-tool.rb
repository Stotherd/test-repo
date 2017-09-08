#!/usr/bin/ruby -w
require 'net/http'
require 'json'
require 'optparse'
require 'ostruct'
require 'etc'
require 'logger'

require_relative 'git_utils'
require_relative 'token_utils'
require_relative 'github_utils'

logger = Logger.new(STDOUT)

help_text = "Ruby script to perform a forward merge and pull request on
shopkeeps ipad-register repo. Run inside the repo.

Running full command:

Either:

This application needs an oauth token to run. Add the oauth token to the key
chain ->

./git_tool.rb --setup --oauth_token [INSERT_OAUTH_KEY_HERE]

And then execute your merge, following prompts ->
./git_tool.rb -l [branch_you_are_on] -m [branch_to_be_merged_in] -k [user/reponame]

For a promptless execution ->
./git_tool.rb -l [branch_you_are_on] -m [branch_to_be_merged_in] -k [user/reponame] -p -g -i
(-p push to master, -g generate pull request, -i promptless)

OR

Put your oauth in the command itself ->
./git_tool.rb -l [branch_you_are_on] -m [branch_to_be_merged_in] -k [user/reponame] --oauth_token [INSERT_OAUTH_KEY_HERE]

Conflicts

Conflicts with the merge will cause the script to pause. Fix the conflicts and
then press enter on the script to continue.

Clean

reverse the attempt to forward merge. This will delete the created
branch, abort the merge and checkout the branch thats the first
parameter. Adding -r will delete the remotely created branch, and by doing so
github will close the Pull Request if one was created.
Some fatal logging may not be fatal. The clean function is a
brute force method that you might want to check has fully cleaned up resources
after.

./git_tool.rb -l [branch_you_are_on] -m [branch_to_be_merged_in] -k [user/reponame] -c -r

How this script normally works:

Builds the forward merge branch name
Verify authentication
fetch/pull to verify branch is up to date, and network is good
    git fetch
    check result of fetch
    git pull
    check result of pull
check that to_be_merged_in_branch exists remotely
if the forward merge branch already exists, remotely or locally, or both,
    check it out,
    update it if neccesary (fetch/pull/merge)
otherwise
    go back to the original branch
    create the new forward merge branch
    perform merge
push to origin (prompt or -p)
create pull request (prompt or -g)
"

options_text = "--repository --oauth --setup --delete_oauth"
options = OpenStruct.new

OptionParser.new do |opt|
  opt.on('-k', '--repository REPONAME', 'repository to be based on') { |o| options.repo_id = o }
  opt.on('-o', '--oauth OAUTHTOKEN', 'The open_auth token for authentication on github') { |o| options.token = o }
  opt.on('-s', '--setup', 'Run with setup to do initial keychain entry') { options.setup = true }
  opt.on('-d', '--delete_oauth', 'Run to delete the oauth token from the keychain') { options.delete_oauth = true }
  opt.on('-l', '--local_branch LOCALBRANCH', 'name of the local branch to be merged into') { |o| options.current_branch = o }
  opt.on('-m', '--to_be_merged TOBEMERGEDBRANCH', 'The name of the branch to be merged in') { |o| options.to_be_merged_in = o }
  opt.on('-c', '--clean', 'Clean up a failed, incomplete or unwanted merge and pull request') { options.clean = true }
  opt.on('-r', '--clean-remote', ' Clean up the remote as well as locally generated branches') { options.clean_remote = true }
  opt.on('-g', '--pull-request', 'Generate a pull request') { options.pull_request = true }
  opt.on('-f', '--force-merge', 'merge without a pull request') { options.force_merge = true }
  opt.on('-p', '--push', 'Push the result to github') { options.push = true }
  opt.on('-i', '--ignore-user-input', 'No prompts for user input') { options.prompt = false }
  opt.on_tail('-h', '--help', 'Shows the help text') do
    puts opt
    logger.info help_text
    exit
  end
end.parse!

token_utilities = TokenUtils.new(logger)
if options.setup == true
  unless options.token
    logger.error 'SCRIPT_LOGGER:: Need an oauth token to set! use -o TOKEN_STRING'
    exit
  end
  token_utilities.save('merge_script', options.token)
  exit
elsif options.delete_oauth == true
  token_utilities.remove('merge_script')
  exit
end

token = token_utilities.find('merge_script')
if token == false
  if defined?(options.token).nil?
    logger.error 'SCRIPT_LOGGER:: No token configured - unable to continue'
    exit
  else
    token = options.token
  end

end

git_utilities = GitUtils.new(logger, Dir.getwd)
github_utilities = GitHubUtils.new(logger, options.repo_id)
if github_utilities.valid_credentials?(token) == false
  logger.error 'Credentials incorrect, please verify your OAuth token is valid'
  exit
end
logger.info 'Credentials authenticated'

if defined?(options.current_branch).nil? || defined?(options.to_be_merged_in).nil? || defined?(options.repo_id).nil?
  logger.error 'Incomplete parameters - please read the handy help text:'
  logger.error help_text
  exit
end

current_branch = options.current_branch
to_be_merged_in_branch = options.to_be_merged_in
forward_branch = "forward-merge-#{to_be_merged_in_branch}-to-#{current_branch}"

if options.clean == true
  git_utilities.forward_merge_clean(current_branch, forward_branch, options.clean_remote)
  exit
end

if github_utilities.does_pull_request_exist?(options.current_branch, options.to_be_merged_in, token)
  if options.prompt != false
    unless git_utilities.get_user_input_to_continue("SCRIPT_LOGGER:: Possible matching pull request detected.
If the branch name generated matches that of a pull request, and the changes are pushed to origin, that pull request will be updated.
Check above logs.
Do you wish to continue? (y/n)")
      exit
    end
  else
    logger.warn 'SCRIPT_LOGGER:: Possible pull request already in progress.'
  end
end

logger.info "SCRIPT_LOGGER:: Merging #{to_be_merged_in_branch} into #{current_branch}"

git_utilities.obtain_latest
git_utilities.checkout_local_branch(current_branch)
git_utilities.obtain_latest
git_utilities.push_to_origin(current_branch)

if git_utilities.remote_branch?(to_be_merged_in_branch) == false
  logger.warn "SCRIPT_LOGGER:: Remote branch #{to_be_merged_in_branch} does not exist - exiting."
  exit
end

local_present = false
remote_present = false
if git_utilities.local_branch?(forward_branch) == true
  logger.warn "SCRIPT_LOGGER:: Forward merge branch #{forward_branch} already locally exists."
  local_present = true
end
if git_utilities.remote_branch?(forward_branch) == true
  logger.warn "SCRIPT_LOGGER:: Forward merge branch #{forward_branch} already remotely exists."
  remote_present = true
end
if local_present || remote_present
  if local_present
    git_utilities.checkout_local_branch(forward_branch)
    if remote_present
      git_utilities.obtain_latest
    else
      git_utilities.push_to_origin(forward_branch) if options.push == true
    end
  elsif remote_present && system("git checkout -b #{forward_branch} origin/#{forward_branch} > /dev/null 2>&1") != true
    logger.error "SCRIPT_LOGGER:: Failed to checkout #{forward_branch} from remote"
    exit
  end
  if git_utilities.branch_up_to_date?(forward_branch, current_branch) != true
    if options.prompt != false
      system("git diff origin/#{current_branch} #{forward_branch}")
      unless git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: The above diff contains the differences between the 2 branches. Do you wish to continue with the merge? (y/n)')
        exit
      end
    end
    logger.info "SCRIPT_LOGGER:: Updating #{forward_branch} with latest from #{current_branch}"
    safe_merge(forward_branch, current_branch)
    git_utilities.push_to_origin(forward_branch) if options.push == true
  end
else
  logger.info "SCRIPT_LOGGER:: Forward merge branch will be called #{forward_branch}"
  if git_utilities.branch_up_to_date?(current_branch, to_be_merged_in_branch) == true
    logger.info "SCRIPT_LOGGER:: We don't need to forward merge these 2 branches. Exiting..."
    exit
  end

  if options.prompt != false
    system("git diff #{current_branch} #{to_be_merged_in_branch}")
    unless git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: The above diff contains the differences between the 2 branches. Do you wish to continue? (y/n)')
      exit
    end
  end

  if system("git checkout -b #{current_branch} origin/#{current_branch} > /dev/null 2>&1") != true
    logger.warn "SCRIPT_LOGGER:: Failed to checkout #{current_branch} from remote, checking if locally available"
    if system("git checkout #{current_branch} > /dev/null 2>&1") != true
      logger.error 'SCRIPT_LOGGER:: Failed to checkout branch locally, unable to continue'
      exit
    end
  end
  logger.info 'SCRIPT_LOGGER:: Successfully checked out the current branch'
  if system("git checkout -b #{forward_branch}") != true
    logger.error 'SCRIPT_LOGGER:: Failed to create new branch.'
    exit
  else
    logger.info 'SCRIPT_LOGGER:: Branch created'
  end
end

git_utilities.safe_merge(forward_branch, to_be_merged_in_branch)

pushed = false
if options.push == true
  logger.info "SCRIPT_LOGGER:: Pushing #{forward_branch} to origin"
  git_utilities.push_to_origin(forward_branch)
  pushed = true
elsif options.prompt != false
  if git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: Do you want to push to master? (Required for pull request)(y/n)')
    logger.info "SCRIPT_LOGGER:: Pushing #{forward_branch} to origin"
    git_utilities.push_to_origin(forward_branch)
    pushed = true
  else
    exit
  end
end

if options.pull_request == true
  if pushed
    logger.info 'SCRIPT_LOGGER:: Creating pull request'
    github_utilities.forward_merge_pull_request(forward_branch, current_branch, token)
  else
    logger.info 'SCRIPT_LOGGER:: Unable to create pull request, as the changes have not been pushed.'
  end
  exit
end

if options.force_merge == true
  git_utilities.final_clean_merge(current_branch, forward_branch)
end

if options.prompt != false
  system("git diff origin/#{forward_branch} #{current_branch}")
  if git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: Based on the above diff, do you want to create a pull request? (y/n)')
      github_utilities.forward_merge_pull_request(forward_branch, current_branch, token)
      exit
  end
  if git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: Do you want to finish the merge without a pull request? (y/n)')
    git_utilities.final_clean_merge(current_branch, forward_branch)
  end
end
