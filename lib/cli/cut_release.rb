require 'fileutils'
require_relative 'code_utils'

class CutRelease
  def initialize(logger, git_utilities, options)
    @logger = logger
    @git_utilities = git_utilities
    token_utilities = TokenUtils.new(logger)
    @token = token_utilities.find('merge_script')
    @github_utilities = GitHubUtils.new(logger, git_utilities.origin_repo_name)
    @options = options
   end

  def release_branch
    @git_utilities.release_branch_name(@options[:version])
  end

  def version_branch
    @git_utilities.release_branch_name("#{@options[:version]}-version-change")
  end

  def cut_release
    return false unless verify_parameters
    return false unless verify_develop_state
    @logger.info "Release branch will be called #{release_branch}"
    @git_utilities.new_branch(release_branch)
    @git_utilities.push(release_branch)
    @git_utilities.new_branch(version_branch)
    code_utilities = CodeUtils.new(@logger)
    return false unless code_utilities.change_xcode_version(@options[:version])
    @git_utilities.add_file_to_commit("../../Register/Register.xcodeproj/project.pbxproj")
    @git_utilities.commit_changes("Updating version number to #{@options[:version]}")
    @git_utilities.push(release_branch)
    @github_utilities.release_version_pull_request(version_branch, release_branch, @token)
    #update dashboard (new file - dashboard_utils?)
    #inform stakeholders * needs email libs and mailing list, and possible slack integration (new file(s) notification?)
    #do Jira stuff (TBD)
    @logger.info 'complete, exiting'
  end

  def verify_parameters
    if @github_utilities.valid_credentials?(@token) == false
      @logger.error 'Credentials incorrect, please verify your OAuth token is valid'
      return false
    end
    @logger.info 'Credentials authenticated'

    if defined?(@options[:version]).nil?
      @logger.error 'Incomplete parameters'
      return false
    end
    true
  end



  def verify_develop_state
    @git_utilities.obtain_latest
    @git_utilities.checkout_local_branch("develop")

    if @git_utilities.remote_branch?("develop") == false
      @logger.error "SCRIPT_LOGGER:: Remote branch develop does not exist."
      return false
    end
    return true
    #check sha if present
  end
end
