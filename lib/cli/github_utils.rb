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

  def does_pull_request_exist?(branch_a, branch_b, oauth_token)
    uri = URI("https://api.github.com/repos/#{@repo_id}/pulls")
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "token #{oauth_token}"
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
    hashed_json = JSON.parse(res.body)
    branch_exists = false
    hashed_json.each do |i|
      if (i['head']['ref'].include? branch_a) &&
         (i['head']['ref'].include? branch_b)
        @logger.info "SCRIPT_LOGGER:: #{i['url']}, #{i['head']['ref']} into
        #{i['base']['ref']}"
        @logger.info 'SCRIPT_LOGGER:: This ^^^ pull request branch name includes
         both branches we want to merge.'
        branch_exists = true

      end
      next unless i['base']['ref'].include? branch_a
      @logger.info "SCRIPT_LOGGER:: #{i['url']}, #{i['head']['ref']}
      into #{i['base']['ref']}"
      @logger.info 'SCRIPT_LOGGER:: This ^^^ pull request base branch is the
      same as the branch we want to merge into.'
      branch_exists = true
    end
    branch_exists
  end

  def forward_merge_pull_request(merge_branch, current_branch, oauth_token)
    uri = URI("https://api.github.com/repos/#{@repo_id}/pulls")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')

    req['Authorization'] = "token #{oauth_token}"
    title = "Automated pull request of #{merge_branch} into #{current_branch}"
    body = "Automated pull request of #{merge_branch}, into the
    #{current_branch} branch"
    req.body = { title: title,
                 body: body,
                 head: merge_branch,
                 base: current_branch }.to_json
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    if res.body.include? 'state":"open'
      issue = issue_url(res.body)
      @logger.info "SCRIPT_LOGGER:: Created pull request:
      #{title}: #{issue}"
    else
      @logger.error 'SCRIPT_LOGGER:: Could not create the pull request -
      response to network request was: '
      @logger.error res.body
      @logger.error "SCRIPT_LOGGER:: reverting back to #{current_branch}"
      system("git checkout #{current_branch} > /dev/null 2>&1")
      @logger.error "SCRIPT_LOGGER:: checked out #{current_branch}."
      @logger.error "SCRIPT_LOGGER::
      ================ The pull request was rejected by github. ================

      Please see log above for an indication of the error. The #{current_branch}
      branch has been checked out.
      Please check the forward-merge branch for changes. Should you wish to
      remove the forward branch, run:
      ./git_tool -l #{current_branch} -m #{merge_branch} -c -r"
      exit
    end
    add_label_to_issue(issue_id(res.body),
                       "⇝ Forward – DON'T SQUASH",
                       oauth_token)
  end

  def add_label_to_issue(issue_number, label, oauth_token)
    uri = URI("https://api.github.com/repos/#{@repo_id}/issues/#{issue_number}/labels")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req['Authorization'] = "token #{oauth_token}"
    req.body = "[\n\"#{label}\"\n]"
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
  end

  def valid_credentials?(oauth_token)
    uri = URI("https://api.github.com/?access_token=#{oauth_token}")
    res = Net::HTTP.get_response(uri)
    res.code == '200'
  end
end
