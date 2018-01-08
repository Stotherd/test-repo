require 'net/http'
require 'nokogiri'

class JenkinsUtils
  def update_build_branch(jenkins_job, branch, oauth_token)
    config_xml = build_http_request(jenkins_job, 'config.xml', 'GET', nil, oauth_token).body
    new_config_xml = change_branch_in_config_file(config_xml, branch)
    build_http_request(jenkins_job, 'config.xml', 'POST', new_config_xml, oauth_token).body
  end

  def change_branch_in_config_file(config_xml, branch_name)
    doc = Nokogiri::XML(config_xml)
    project = doc.at_css 'project'
    properties = project.at_css 'properties'
    parameters = properties.at_css 'parameterDefinitions'
    branch = parameters.at_css 'defaultValue'
    branch.content = branch_name
    doc.to_xml
  end

  def build_http_request(jenkins_job, uri_tail, type, body, oauth_token)
    uri = URI("https://jenkins-ios.posrip.com/job/#{jenkins_job}/#{uri_tail}")
    if type == 'POST'
      req = Net::HTTP::Post.new(uri)
      req.body = body
    elsif type == 'GET'
      req = Net::HTTP::Get.new(uri)
    end
    req.basic_auth nil, oauth_token
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
  end
end
