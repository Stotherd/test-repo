# frozen_string_literal: true

require 'logger'

# none of these are needed yet (but will be)
require_relative 'git_utils'
require_relative 'token_utils'
require_relative 'github_utils'
require_relative 'forward_merge'
require_relative 'cut_release'
require_relative 'dashboard_utils'
require_relative 'notification'
require_relative 'jenkins_utils'

module Gitkeep
  module CLI
    help_text = 'Does release stuff'
    desc help_text

    desc 'Cut a release branch and perform post release steps'
    arg_name '<args>...', %i[multiple]
    command :cut_release do |c|
      c.desc 'The version number to be used'
      c.flag %i[v version], type: String
      c.desc 'sha to be used (Default head of develop)'
      c.flag %i[s sha], type: String
      c.desc 'The previous release branch name'
      c.flag %i[p previous_branch], type: String
      c.desc 'Test Mode - does no external operations but logs web requests and git operations instead.'
      c.switch %i[t test_mode]
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info "Cutting release for #{options[:version]}."
        git_utilities = GitUtils.new(logger, options[:test_mode])
        release_cutter = CutRelease.new(logger, git_utilities, options)
        release_cutter.cut_release
      end
    end
    command :notify_branch_creation do |c|
      c.desc 'The new release branch name'
      c.flag %i[v version], type: String
      c.desc 'The previous release branch name'
      c.flag %i[p previous_branch], type: String
      c.desc 'Test Mode - does no external operations but logs web requests and git operations instead.'
      c.switch %i[t test_mode]
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info "Sending branch creation notification: #{options[:version]}"
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        notification = Notification.new(logger, git_utilities, options)
        notification.email_branch_creation(release_cutter.get_prs_for_release)
      end
    end
    command :get_open_prs do |c|
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get open PRs'
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        release_cutter.open_pull_requests
      end
    end
    command :get_closed_prs do |c|
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get closed PRs'
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        release_cutter.closed_pull_requests
      end
    end
    command :get_pr do |c|
      c.desc 'The PR number'
      c.flag %i[n pr_number], type: String

      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get PR'
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        release_cutter.single_pull_request
      end
    end
    command :get_releases do |c|
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get Releases'
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        release_cutter.releases
      end
    end
    command :get_commits_for_release do |c|
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get commits for release'
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        puts release_cutter.commits_for_release
      end
    end
    command :get_prs_for_release do |c|
      c.desc 'The previous release branch name'
      c.flag %i[p previous_branch], type: String

      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get PRs for release'
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        puts release_cutter.get_prs_for_release
      end
    end
    command :get_single_commit do |c|
      c.desc 'The commit sha'
      c.flag %i[s sha], type: String

      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get commit'
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        release_cutter.single_commit
      end
    end
    command :modify_jenkins do |c|
      c.desc 'branch'
      c.flag %i[b branch], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get commit'
        jenkins_utils = JenkinsUtils.new
        token_utilities = TokenUtils.new(logger)
        oauth_token = token_utilities.find('merge_script')
        jenkins_utils.update_pr_tester_for_new_release(options[:branch], oauth_token)
      end
    end
  end
end
