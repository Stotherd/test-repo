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
        notification.email_branch_creation(release_cutter.prs_for_release)
      end
    end
    command :open_prs do |c|
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get open PRs'
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        release_cutter.open_pull_requests
      end
    end
    command :closed_prs do |c|
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get closed PRs'
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        release_cutter.closed_pull_requests
      end
    end
    command :pr do |c|
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
    command :releases do |c|
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get Releases'
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        release_cutter.releases
      end
    end
    command :commits_for_release do |c|
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get commits for release'
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        puts release_cutter.commits_for_release
      end
    end
    command :prs_for_release do |c|
      c.desc 'The previous release branch name'
      c.flag %i[p previous_branch], type: String

      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get PRs for release'
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        puts release_cutter.prs_for_release
      end
    end
    command :single_commit do |c|
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
    command :add_tag do |c|
      c.desc 'The version number to be used'
      c.flag %i[v version], type: String
      c.desc 'Test Mode - does no external operations but logs web requests and git operations instead.'
      c.switch %i[t test_mode]

      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info "Adding tag cut-#{options[:version]}"
        git_utilities = GitUtils.new(logger, options[:test_mode])
        git_utilities.add_tag("cut-#{options[:version]}")
      end
    end
  end
end
