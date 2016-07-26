module OmniContacts
  module Importer

    autoload :Gmail, "omnicontacts/importer/gmail"
    autoload :Yahoo, "omnicontacts/importer/yahoo"
    autoload :Hotmail, "omnicontacts/importer/hotmail"
    autoload :Facebook, "omnicontacts/importer/facebook"
    autoload :Linkedin, "omnicontacts/importer/linkedin"
    autoload :Exchange, "omnicontacts/importer/exchange"

  end
end
