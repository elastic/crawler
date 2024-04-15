# frozen_string_literal: true

java_import javax.net.ssl.X509TrustManager

# A simple implementation of the trust manager interface that trusts everyone
# Used by the Crawler HTTP client to implement ssl_verification_mode=none.
module Crawler
  module HttpUtils
    class AllTrustingTrustManager
      include X509TrustManager

      # rubocop:disable Naming/MethodName
      def checkClientTrusted(*)
        true
      end

      def checkServerTrusted(*)
        true
      end

      def getAcceptedIssuers
        []
      end
      # rubocop:enable Naming/MethodName
    end
  end
end
