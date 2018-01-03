require_relative 'email'

class Notification
  def initialize(logger, git_utilities, options)
    @logger = logger
    @git_utilities = git_utilities
    @options = options
  end

  def release_branch
    @git_utilities.release_branch_name(@options[:version])
  end

  def email_branch_creation
    @logger.info 'Sending email: Branch creation and release preparation'
    send_email @logger, email_subject: "New branch created: #{release_branch}", email_body: "Branch #{release_branch} has been created and we are preparing for a release."
  end
end
