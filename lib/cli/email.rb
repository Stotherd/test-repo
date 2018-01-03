require 'mail'

require_relative 'token_utils'

def send_email(logger,opts={})

  token_utilities = TokenUtils.new(logger)

  opts[:address]              ||= 'smtp.gmail.com'
  opts[:port]                 ||= '587'
  opts[:user_name]            ||= token_utilities.find('merge_script_email_address')
  opts[:password]             ||= token_utilities.find('merge_script_email_password')
  opts[:authentication]       ||= 'plain'
  opts[:enable_starttls_auto] ||= true
  opts[:email_to]             ||= 'lelmore@shopkeep.com'
  opts[:email_from]           ||= 'cornerstone@shopkeep.com'
  opts[:email_from_alias]     ||= 'Cornerstone'
  opts[:email_subject]        ||= 'Testing ruby subject'
  opts[:email_body]           ||= 'Ruby it'

  Mail.defaults do
    delivery_method :smtp, opts
  end

  Mail.deliver do
         to opts[:email_to]
       from opts[:email_from_alias] + "<" + opts[:email_from] + ">"
    subject opts[:email_subject]
       body opts[:email_body]
  end
end
