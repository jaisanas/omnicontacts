require "omnicontacts/middleware/oauth2"
require "omnicontacts/parse_utils"
require "json"

module OmniContacts
  module Importer
    class Exchange < Middleware::OAuth2
      include ParseUtils

      attr_reader :auth_host, :authorize_path, :auth_token_path, :scope

      def initialize app, client_id, client_secret, options ={}
        super app, client_id, client_secret, options
        @auth_host = "login.microsoftonline.com"
        @authorize_path = "/common/oauth2/authorize"
        @scope = options[:permissions] || "https://outlook.office.com/contacts.read https://outlook.office.com/mail.read"
        @auth_token_path = "/common/oauth2/token"
        @contacts_host = "outlook.office365.com"
        @contacts_path = "/v2.0/me/contacts"
        @self_path = "/v2.0/me"
      end

      def fetch_access_token code
        client = ::OAuth2::Client.new(client_id,
                              client_secret,
                              :site => "https://#{auth_host}",
                              :authorize_url => @authorize_path,
                              :token_url => @auth_token_path)
        token = client.auth_code.get_token(code,
                                     :redirect_uri => redirect_uri,
                                     :resource => "https://#{@contacts_host}")
        access_token_from_response token
      end

      def fetch_contacts_using_access_token access_token, token_type, refresh_token = nil
        fetch_current_token(access_token, token_type, refresh_token)
        fetch_current_user(access_token)
        contacts_response = fetch_contacts_data access_token
        contacts_from_response contacts_response
      end

      def fetch_contacts_data access_token
        view_size = 300
        page = 1
        fields = nil
        sort = nil
        user = nil
        request_url = "/api/v2.0/" << (user.nil? ? "Me/" : ("users/" << user)) << "Contacts"
        request_params = {
          '$top' => view_size,
          '$skip' => (page - 1) * view_size
        }

        if not fields.nil?
          request_params['$select'] = fields.join(',')
        end

        if not sort.nil?
          request_params['$orderby'] = sort[:sort_field] + " " + sort[:sort_order]
        end

        outlook_client  = RubyOutlook::Client.new
        response_as_json   = outlook_client.make_api_call "GET", request_url, access_token, request_params
      end

      def fetch_current_token access_token, token_type, refresh_token
        token = current_token(access_token, token_type, refresh_token)
        set_current_token token
      end

      def fetch_current_user access_token
        view_size = 10
        page = 1
        fields = nil
        sort = nil
        user = nil
        request_url = "/api/v2.0/" << (user.nil? ? "Me" : ("users/" << user))
        request_params = {
          '$top' => view_size,
          '$skip' => (page - 1) * view_size
        }

        if not fields.nil?
          request_params['$select'] = fields.join(',')
        end

        if not sort.nil?
          request_params['$orderby'] = sort[:sort_field] + " " + sort[:sort_order]
        end

        outlook_client  = RubyOutlook::Client.new
        self_response   = outlook_client.make_api_call "GET", request_url, access_token, request_params

        user = current_user self_response
        set_current_user user
        set_current_email user
      end

      private
      def current_token access_token, token_type, refresh_token
        {access_token: access_token, token_type: token_type, refresh_token: refresh_token}
      end

      def contacts_from_response response_as_json
        return nil if response_as_json.blank?
        response = JSON.parse(response_as_json)
        contacts = []
        response['value'].each do |entry|
          # creating nil fields to keep the fields consistent across other networks
          contact = {:id => nil, :first_name => nil, :last_name => nil, :name => nil, :email => nil, :gender => nil, :birthday => nil, :profile_picture=> nil, :relation => nil, :email_hashes => []}
          contact[:id] = entry['Id'] ? entry['Id'] : entry['id']
          contact[:email] = (entry['EmailAddresses'][0]['Address'] rescue nil) #parse_email(emails) if valid_email? parse_email(emails)
          contact[:first_name] = normalize_name(entry['GivenName'])
          contact[:last_name] = normalize_name(entry['Surname'])
          contact[:name] = normalize_name(entry['DisplayName'])
          contact[:birthday] = nil #birthday_format(entry['birth_month'], entry['birth_day'], entry['birth_year'])
          contact[:gender] = nil #entry['gender']
          contact[:profile_picture] = nil #image_url(entry['user_id'])
          contact[:email_hashes] = nil #entry['email_hashes']
          contacts << contact if contact[:name] || contact[:first_name]
        end
        contacts
      end

      def parse_email(emails)
        return nil if emails.nil?
        emails['account'] || emails['preferred'] || emails['personal'] || emails['business'] || emails['other']
      end

      def current_user me
        return nil if me.nil?
        me = JSON.parse(me)
        email = me["EmailAddress"]
        user = {:id => me['Id'], :emailAddress => email, :email => email, :name => me['DisplayName'], :first_name => me['first_name'],
                :last_name => me['last_name'], :gender => me['gender'], :profile_picture => image_url(me['id']),
                :birthday => birthday_format(me['birth_month'], me['birth_day'], me['birth_year'])
        }
        user
      end

      def image_url hotmail_id
        return 'https://apis.live.net/v5.0/' + hotmail_id + '/picture' if hotmail_id
      end

      def escape_windows_format value
        value.gsub(/[\r\s]/, '')
      end

      def valid_email? value
        /\A[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+\z/.match(value)
      end

    end
  end
end
