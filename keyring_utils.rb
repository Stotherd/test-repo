class KeyringUtils

    def initialize(logger)
        $logger = logger
    end

    def set_token(app_name, token)
        self.remove_token(app_name)
        if system("security add-generic-password -a #{ENV['USER']} -s #{app_name} -w #{token}")
            $logger.info "SCRIPT_LOGGER:: Key added to keychain"
        else
            $logger.error "unable to add key to keychain"
        end
    end

    def remove_token(app_name)
        if system("security delete-generic-password -a #{ENV['USER']} -s #{app_name}")
            $logger.info "SCRIPT_LOGGER:: Key removed from keychain"
        end
    end

    def get_token(app_name)
        oauth = %x(security find-generic-password -a #{ENV['USER']} -s #{app_name} -w)
        return oauth.chomp
    end


end
