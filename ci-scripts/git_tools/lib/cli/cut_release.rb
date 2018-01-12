# frozen_string_literal: true

require 'fileutils'
require_relative 'code_utils'
require_relative 'dashboard_utils'
require_relative 'jenkins_utils'

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
    @git_utilities.push_to_origin(release_branch)
    @git_utilities.new_branch(version_branch)
    code_utilities = CodeUtils.new(@logger)
    return false unless code_utilities.change_xcode_version(@options[:version])
    @git_utilities.add_file_to_commit('../../Register/Register.xcodeproj/project.pbxproj')
    @git_utilities.commit_changes("Updating version number to #{@options[:version]}")
    @git_utilities.push_to_origin(version_branch)
    jenkins_utils = JenkinsUtils.new
    jenkin_utils.update_pr_tester_for_new_release(release_branch, @token)
    @github_utilities.release_version_pull_request(version_branch, release_branch, @token)
    dashboard_utils = DashboardUtils.new(@logger)
    dashboard_utils.dashboard_cut_new_release(@options[:version], release_branch)
    notification = Notification.new(@logger, @git_utilities, @options)
    notification.email_branch_creation(get_prs_for_release)
    jenkins_utils.update_build_branch('main_regression_multijob_branch', release_branch, @token, 'REGISTER_BRANCH')
    jenkins_utils.update_build_branch('Register-Beta-iTunes-Builder', release_branch, @token, 'BRANCH_TO_BUILD')
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
    @git_utilities.checkout_local_branch('develop')

    if @git_utilities.remote_branch?('develop') == false
      @logger.error 'SCRIPT_LOGGER:: Remote branch develop does not exist.'
      return false
    end
    true
    # check sha if present
  end

  def open_pull_requests
    @github_utilities.get_open_pull_requests(@token)
  end

  def closed_pull_requests
    @github_utilities.get_closed_pull_requests(@token)
  end

  def single_pull_request
    @github_utilities.get_single_pull_request(@token, @options[:pr_number])
  end

  def releases
    @github_utilities.get_releases(@token)
  end

  def single_commit
    @github_utilities.get_single_commit(@token, @options[:sha])
  end

  def verify_branch?
    if @git_utilities.remote_branch?(@options[:previous_branch]) == false
      @logger.warn 'Requested previous branch does not exist on remote: ' + @options[:previous_branch]
      @logger.info 'Check your branch name and try again'
      exit
    end
    true
  end

  def commits_for_release
    return nil unless verify_branch?
    @logger.info "Finding commits that are in origin/develop and not in origin/#{@options[:previous_branch]} (no merges)"
    str_result = `git log origin/#{@options[:previous_branch]}..origin/develop --oneline --no-merges`
    str_array = str_result.split "\n"
    result = []
    str_array.each do |str_|
      result.push(str_.to_s.rpartition('/').last)
    end
    result
  end

  def get_commit_shas_for_release
    return nil unless verify_branch?
    @logger.info "Finding commits that are in origin/develop and not in origin/#{@options[:previous_branch]} (no merges)"
    str_result = `git log origin/#{@options[:previous_branch]}..origin/develop --format=format:%h --no-merges`
    str_array = str_result.split "\n"
    result = []
    str_array.each do |str_|
      result.push(str_.to_s.rpartition('/').last)
    end
    result
  end

  def get_prs_for_release
    results = get_commit_shas_for_release
    if results.count.positive?
      return @github_utilities.get_prs_for_release(@token, results.last)
    else
      @logger.warn 'No commits found in git log'
      exit
    end
  end
end
