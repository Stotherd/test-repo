# Utilites for using the github api
require 'net/http'
require 'json'
require 'ostruct'
require 'date'

class DashboardUtils
  def initialize(log)
    @logger = log
  end

  def dashboard_cut_new_release(version, branch_name)
    return false unless !release_exists?(version)
    create_release(version, branch_name)
    #fire request to create a new release (no build yet)
    #fire request to set state to state N.B should be Alpha for a new release
  end

  def change_release_state_to_beta(version, build)
    return false unless release_exists?(version)
    #set build with date
    #set state
  end

  def release_release(version, build)
    return false unless release_exists?(version)
    #set build with date
    #set state
  end

  def build_http_request(uri_tail, type, body)
    uri = URI("http://releases.office.production.posrip.com/releases/#{uri_tail}")
    if type == 'POST'
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = body
    elsif type == 'GET'
      req = Net::HTTP::Get.new(uri)
    end
    @logger.info "req"
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: false) do |http|
      http.request(req)
    end
  end

  def release_exists?(version)
    uri = URI("http://releases.office.production.posrip.com/releases")
    res = Net::HTTP.get_response(uri)
    res.body.include? "version\": \"#{version}"
  end

  def current_date
    date = Time.new
    date.year.to_s + "-" + date.month.to_s + "-" + date.day.to_s
  end

  def create_release(version_name, branch_name)
    body = { version: version_name,
             code_complete_date: current_date,
             branch_name: branch_name,
             state: "alpha" }.to_json
    res = build_http_request('/releases', 'POST', body)
    @logger.info res
  end
end
