# frozen_string_literal: true

java_import javax.net.ssl.X509TrustManager

# A simple implementation of the trust manager interface that trusts everyone
# Used by the Crawler HTTP client to implement ssl_verification_mode=none.
module Crawler
  module HttpClient
    class AllTrustingTrustManager
      include X509TrustManager

      def checkClientTrusted(*)
        true
      end

      def checkServerTrusted(*)
        true
      end

      def getAcceptedIssuers
        []
      end
    end
  end
end
