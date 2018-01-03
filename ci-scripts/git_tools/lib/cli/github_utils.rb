# Utilites for using the github api
require 'net/http'
require 'json'
require 'ostruct'
class GitHubUtils
  def initialize(log, repo_id)
    @logger = log
    @repo_id = repo_id
  end

  def issue_id(body)
    hashed_json = JSON.parse(body)
    hashed_json['number']
  end

  def issue_url(body)
    hashed_json = JSON.parse(body)
    hashed_json['url']
  end

  def build_http_request(uri_tail, type, body, oauth_token)
    uri = URI("https://api.github.com/repos/#{@repo_id}#{uri_tail}")
    if type == 'POST'
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = body
    elsif type == 'GET'
      req = Net::HTTP::Get.new(uri)
    end
    req['Authorization'] = "token #{oauth_token}"
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
  end

  def both_branches_present?(url, head, base, branch_a, branch_b)
    return false unless head.include? branch_a
    return false unless base.include? branch_b
    @logger.info "SCRIPT_LOGGER:: #{url}, #{head} into #{base}"
    @logger.info 'SCRIPT_LOGGER:: This ^^^ pull request branch name includes both branches we want to merge.'
    true
  end

  def branch_present?(url, head, base, branch_a)
    return false unless (i['base']['ref']).include? branch_a
    @logger.info "SCRIPT_LOGGER:: #{url}, #{head} into #{base}"
    @logger.info 'SCRIPT_LOGGER:: This ^^^ pull request base branch is the same as the branch we want to merge into.'
    true
  end

  def does_pull_request_exist?(branch_a, branch_b, oauth_token)
    branch_exists = false
    JSON.parse(build_http_request('/pulls', 'GET', nil, oauth_token).body).each do |i|
      branch_exists = both_branches_present?(i['url'], i['head']['ref'], i['base']['ref'], branch_a, branch_b)
      next unless branch_present?(url, head, base, branch_a)
      branch_exists = true
    end
    branch_exists
  end

  def verify_pull_request_opened?(body, title, current_branch)
    if pull_request_opened?(body)
      @logger.info "SCRIPT_LOGGER:: Created pull request:
      #{title}: #{issue_url(body)}"
    else
      @logger.error 'SCRIPT_LOGGER:: Could not create the pull request -
      response to network request was: '
      @logger.error res.body
      @logger.error "SCRIPT_LOGGER:: reverting back to #{current_branch}"
      system("git checkout #{current_branch} > /dev/null 2>&1")
      @logger.error "SCRIPT_LOGGER::
      ================ The pull request was rejected by github. ================

      Please see log above for an indication of the error. The #{current_branch}
      branch has been checked out."
      exit
    end
  end

  def forward_merge_pull_request(merge_branch, current_branch, oauth_token)
    text = "Automated pull request of #{merge_branch} into #{current_branch}"
    res = build_http_request('/pulls', 'POST', { title: text,
                                                 body: text,
                                                 head: merge_branch,
                                                 base: current_branch }.to_json, oauth_token)
    verify_pull_request_opened?(res.body, text, current_branch)
    add_label_to_issue(issue_id(res.body),
                       "⇝ Forward – DON'T SQUASH",
                       oauth_token)
  end

  def pull_request_opened?(body)
    body.include? 'state":"open'
  end

  def release_version_pull_request(version_branch, release_branch, oauth_token)
    title = "Bumping version number for #{release_branch}"
    body_text = "Automated pull request to bump the version number for #{release_branch}"
    res = build_http_request('/pulls', 'POST', { title: title,
                                                 body: body_text,
                                                 head: version_branch,
                                                 base: release_branch }.to_json, oauth_token)
    verify_pull_request_opened?(res.body, text, current_branch)
  end

  def add_label_to_issue(issue_number, label, oauth_token)
    build_http_request("/issues/#{issue_number}/labels", 'POST', "[\n\"#{label}\"\n]", oauth_token)
  end

  def valid_credentials?(oauth_token)
    uri = URI("https://api.github.com/?access_token=#{oauth_token}")
    res = Net::HTTP.get_response(uri)
    res.code == '200'
  end
end
