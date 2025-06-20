#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

java_import 'org.jsoup.Jsoup'

RSpec.describe(Crawler::ContentEngine::Utils) do
  describe '.node_descendant_text' do
    it 'should raise an error unless given a node object' do
      expect do
        Crawler::ContentEngine::Utils.node_descendant_text('something')
      end.to raise_error(ArgumentError, /node-like/)
    end

    it 'should replace break tags with spaces' do
      node = Jsoup.parse('<body>Hello,<br>World!')
      expect(Crawler::ContentEngine::Utils.node_descendant_text(node)).to eq('Hello, World!')
    end

    context 'with uncrate.com pages' do
      let(:content) { read_fixture('uncrate.com.html') }
      let(:html) { Jsoup.parse(content) }

      it 'should have a reasonable performance' do
        duration = Benchmark.measure do
          Crawler::ContentEngine::Utils.node_descendant_text(html)
        end

        # It usually takes ~250 msec, used to take 180 sec before we fixed it, so let's aim for something reasonable
        expect(duration.real).to be < 5
      end
    end

    context 'with ignore_tags' do
      it 'ignores <script> tags' do
        node = Jsoup.parse('<div><script>Script body</script><p>P body</p></div>')
        expect(Crawler::ContentEngine::Utils.node_descendant_text(node)).to eq('P body')
      end
    end

    context 'without ignore_tags' do
      it 'does not ignores <script> tags' do
        node = Jsoup.parse('<div><script>Script body</script><p>P body</p></div>')
        expect(Crawler::ContentEngine::Utils.node_descendant_text(node, [])).to eq('Script body P body')
      end
    end
  end
end
