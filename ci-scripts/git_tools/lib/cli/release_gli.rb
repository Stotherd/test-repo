require 'logger'

# none of these are needed yet (but will be)
require_relative 'git_utils'
require_relative 'token_utils'
require_relative 'github_utils'
require_relative 'forward_merge'
require_relative 'cut_release'
require_relative 'dashboard_utils'
require_relative 'notification'

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
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info "Cutting release for #{options[:version]}."
        git_utilities = GitUtils.new(logger)
        release_cutter = CutRelease.new(logger, git_utilities, options)
        release_cutter.cut_release
        notification = Notification.new(logger, git_utilities, options)
        notification.email_branch_creation
        # do Jira stuff (TBD)
      end
    end
    command :notify_branch_creation do |c|
      c.desc 'The new release branch name'
      c.flag %i[v version], type: String

      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info "Sending branch creation notification: #{options[:version]}"
        git_utilities = GitUtils.new(logger)
        notification = Notification.new(logger, git_utilities, options)
        notification.email_branch_creation
      end
    end
  end
end
