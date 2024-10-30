#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

java_import javax.net.ssl.X509TrustManager

# A simple implementation of the trust manager interface that trusts everyone
# Used by the Crawler HTTP client to implement ssl_verification_mode=none.
module Crawler
  module Http
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
