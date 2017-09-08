require 'logger'

require_relative 'git_utils'
require_relative 'token_utils'
require_relative 'github_utils'

module Gittool
  module CLI
    help_text = "Performs a forward merge and pull request on
    shopkeeps ipad-register repo. Run inside the repo.

    Requires gems ruby-git and gli.

    Running full command:

    Either:

    This application needs an oauth token to run. Add the oauth token to the key
    chain ->

    bin/gittool setup --oauth_token [INSERT_OAUTH_KEY_HERE]

    And then execute your merge, following prompts ->
    bin/gittool forward_merge -b [branch_you_are_on] -m [branch_to_be_merged_in] -k [user/reponame]

    For a promptless execution ->
    bin/gittool forward_merge -b [branch_you_are_on] -m [branch_to_be_merged_in] -k [user/reponame] -p -g -a
    (-p push to master, -g generate pull request, -a automatic)

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

    bin/gittool clean -b [branch_you_are_on] -m [branch_to_be_merged_in] -k [user/reponame]

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
    desc help_text
    arg_name '<args>...', %i[multiple]
    command :forward_merge do |c|
      c.desc 'Pass a base_branch'
      c.flag %i[b base_branch], type: String
      c.desc 'Pass a merge branch'
      c.flag %i[m merge_branch], type: String
      c.desc 'Pass a repo name e.g. Shopkeep/ipad-register'
      c.flag %i[r repo_name], type: String

      c.desc 'Push the generated branch to master'
      c.switch %i[p push]
      c.desc 'Generate a pull request'
      c.switch %i[g generate_pull_request]
      c.desc 'Run through script with no user input where possible'
      c.switch %i[a automatic]
      c.desc 'Push up without a pull request'
      c.switch %i[f force_merge]
      c.action do |_global_options, options, _args|
        logger = Logger.new(STDOUT)
        token_utilities = TokenUtils.new(logger)
        token = token_utilities.find('merge_script')

        git_utilities = GitUtils.new(logger, Dir.getwd)
        github_utilities = GitHubUtils.new(logger, options[:repo_name])
        if github_utilities.valid_credentials?(token) == false
          logger.error 'Credentials incorrect, please verify your OAuth token is valid'
          exit
        end
        logger.info 'Credentials authenticated'
        current_branch = options[:base_branch]
        merge_branch = options[:merge_branch]

        if defined?(options[:merge_branch]).nil? || defined?(options[:base_branch]).nil? || defined?(options[:repo_name]).nil?
          logger.error 'Incomplete parameters - please read the handy help text:'
          logger.error help_text
          exit
        end

        if github_utilities.does_pull_request_exist?(current_branch, merge_branch, token)
          if options[:automatic]
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

        logger.info "SCRIPT_LOGGER:: Merging #{options[:merge_branch]} into #{options[:base_branch]}"

        git_utilities.obtain_latest
        git_utilities.checkout_local_branch(options[:base_branch])
        git_utilities.obtain_latest
        git_utilities.push_to_origin(options[:base_branch])

        if git_utilities.remote_branch?(options[:merge_branch]) == false
          logger.warn "SCRIPT_LOGGER:: Remote branch #{options[:merge_branch]} does not exist - exiting."
          exit
        end

        local_present = false
        remote_present = false

        forward_branch = git_utilities.forward_branch_name(options[:base_branch], options[:merge_branch])
        puts forward_branch
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
            elsif options[:push] == true
              git_utilities.push_to_origin(forward_branch)
            end
          elsif remote_present && system("git checkout -b #{forward_branch} origin/#{forward_branch} > /dev/null 2>&1") != true
            logger.error "SCRIPT_LOGGER:: Failed to checkout #{forward_branch} from remote"
            exit
          end
          if git_utilities.branch_up_to_date?(forward_branch, options[:base_branch]) != true
            if options[:automatic]
              system("git diff origin/#{options[:base_branch]} #{forward_branch}")
              unless git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: The above diff contains the differences between the 2 branches. Do you wish to continue with the merge? (y/n)')
                exit
              end
            end
            logger.info "SCRIPT_LOGGER:: Updating #{forward_branch} with latest from #{current_branch}"
            safe_merge(forward_branch, options[:base_branch])
            git_utilities.push_to_origin(forward_branch) if options[:push] == true
          end
        else
          logger.info "SCRIPT_LOGGER:: Forward merge branch will be called #{forward_branch}"
          if git_utilities.branch_up_to_date?(options[:base_branch], options[:merge_branch]) == true
            logger.info "SCRIPT_LOGGER:: We don't need to forward merge these 2 branches. Exiting..."
            exit
          end

          if options[:automatic]
            system("git diff #{options[:base_branch]} #{options[:merge_branch]}")
            unless git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: The above diff contains the differences between the 2 branches. Do you wish to continue? (y/n)')
              exit
            end
          end

          if system("git checkout -b #{options[:base_branch]} origin/#{options[:base_branch]} > /dev/null 2>&1") != true
            logger.warn "SCRIPT_LOGGER:: Failed to checkout #{options[:base_branch]} from remote, checking if locally available"
            if system("git checkout #{options[:base_branch]} > /dev/null 2>&1") != true
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

        git_utilities.safe_merge(forward_branch, options[:merge_branch])

        pushed = false
        if options[:push]
          logger.info "SCRIPT_LOGGER:: Pushing #{forward_branch} to origin"
          git_utilities.push_to_origin(forward_branch)
          pushed = true
        elsif options[:automatic]
          if git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: Do you want to push to master? (Required for pull request)(y/n)')
            logger.info "SCRIPT_LOGGER:: Pushing #{forward_branch} to origin"
            git_utilities.push_to_origin(forward_branch)
            pushed = true
          else
            exit
          end
        end

        if options[:generate_pull_request]
          if pushed
            logger.info 'SCRIPT_LOGGER:: Creating pull request'
            github_utilities.forward_merge_pull_request(forward_branch, current_branch, token)
          else
            logger.info 'SCRIPT_LOGGER:: Unable to create pull request, as the changes have not been pushed.'
          end
          exit
        end

        if options[:force_merge]
          git_utilities.final_clean_merge(current_branch, forward_branch)
        end

        if options[:automatic]
          system("git diff origin/#{forward_branch} #{options[:base_branch]}")
          if git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: Based on the above diff, do you want to create a pull request? (y/n)')
            github_utilities.forward_merge_pull_request(forward_branch, options[:base_branch], token)
            exit
          end
          if git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: Do you want to finish the merge without a pull request? (y/n)')
            git_utilities.final_clean_merge(options[:base_branch], forward_branch)
          end
        end
      end
    end
    desc 'Clean up a previous aborted forward merge request'
    arg_name '<args>...', %i[multiple]
    command :clean do |c|
      c.desc 'Pass a base_branch'
      c.flag %i[b base_branch], type: String
      c.desc 'Pass a merge branch'
      c.flag %i[m merge_branch], type: String
      c.desc 'Pass a repo name e.g. Shopkeep/ipad-register'
      c.flag %i[r repo_name], type: String
      c.desc 'Clean up remote branch too'
      c.switch %i[p push_delete_to_origin]

      c.action do |_global_options, options, _args|
        logger = Logger.new(STDOUT)
        git_utilities = GitUtils.new(logger, Dir.getwd)
        forward_branch = git_utilities.forward_branch_name(options[:base_branch], options[:merge_branch])
        git_utilities.forward_merge_clean(options[:base_branch], forward_branch, options[:push_delete_to_origin])
      end
    end
    desc 'Oauth token setup for forward merge script'
    arg_name '<args>...', %i[multiple]
    command :setup do |c|
      c.desc 'The oauth token to be used in setup'
      c.flag %i[o oauth_token], type: String
      c.desc 'Delete the configured oauth token for the merge script'
      c.switch %i[d delete_token]
      c.action do |_global_options, options, _args|
        logger = Logger.new(STDOUT)
        token_utilities = TokenUtils.new(logger)
        if options[:delete_token]
          token_utilities.remove('merge_script')
        else
          unless options[:oauth_token]
            logger.error 'SCRIPT_LOGGER:: Need an oauth token to set! use -o TOKEN_STRING'
            exit
          end
          token_utilities.save('merge_script', options[:oauth_token])
        end
      end
    end
  end
end
