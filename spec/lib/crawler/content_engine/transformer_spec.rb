#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

java_import 'org.jsoup.Jsoup'

RSpec.describe(Crawler::ContentEngine::Transformer) do
  describe '.transform!' do
    let(:doc) { Jsoup.parse(html) }
    let(:body_tag) { doc.body }

    def document_body
      transformed_body_tag = described_class.transform(body_tag)
      Crawler::ContentEngine::Utils.node_descendant_text(transformed_body_tag)
    end

    context 'simple inclusion rule' do
      let(:html) do
        <<-HTML
          <body>
            test1
            <div data-elastic-include>test2</div>
            test3
          </body>
        HTML
      end

      it 'should return expected document body' do
        expect(document_body).to eq('test1 test2 test3')
      end
    end

    context 'simple exclusion rule' do
      let(:html) do
        <<-HTML
          <body>
            test1
            <div data-elastic-exclude>test2</div>
            test3
          </body>
        HTML
      end

      it 'should return expected document body' do
        expect(document_body).to eq('test1 test3')
      end
    end

    context 'exclude followed by an include' do
      let(:html) do
        <<-HTML
          <body>
            test1
            <div data-elastic-exclude>test2</div>
            <div data-elastic-include>test3</div>
            test4
          </body>
        HTML
      end

      it 'should return expected document body' do
        expect(document_body).to eq('test1 test3 test4')
      end
    end

    context 'include followed by an exclude' do
      let(:html) do
        <<-HTML
          <body>
            test1
            <div data-elastic-include>test2</div>
            <div data-elastic-exclude>test3</div>
            test4
          </body>
        HTML
      end

      it 'should return expected document body' do
        expect(document_body).to eq('test1 test2 test4')
      end
    end

    context 'nested inclusion rules' do
      let(:html) do
        <<-HTML
          <body>
            test1
            <div data-elastic-include>
              test2
              <span data-elastic-include>test21</span>
              test3
            </div>
            test4
          </body>
        HTML
      end

      it 'should return expected document body' do
        expect(document_body).to eq('test1 test2 test21 test3 test4')
      end
    end

    context 'nested inclusion and exclusion rules, example 1' do
      let(:html) do
        <<-HTML
          <body>
            test1
            <div data-elastic-exclude>
              test2
              <span data-elastic-include>test3</span>
              test4
            </div>
            test5
          </body>
        HTML
      end

      it 'should return expected document body' do
        expect(document_body).to eq('test1 test3 test5')
      end
    end

    context 'nested inclusion and exclusion rules, example 2' do
      let(:html) do
        <<-HTML
          <body>
            test1
            <div data-elastic-exclude>
              test2
              <div data-elastic-include>
                test3
                <span data-elastic-exclude>
                  test4
                  <span data-elastic-include>test5</span>
                </span>
              </div>
              test6
            </div>
            test7
          </body>
        HTML
      end

      it 'should return expected document body' do
        expect(document_body).to eq('test1 test3 test5 test7')
      end
    end

    # See https://github.com/elastic/enterprise-search-team/issues/1917
    context 'nested inclusion and exclusion rules, example 3' do
      let(:html) do
        <<-HTML
          <body>
            <div data-elastic-exclude>
              <div>
                <ul class='outer'>
                  <li class='outer1'> Why
                    <div>
                      <ul class='inner1'><li class='inner11'></li></ul>
                    </div>
                  </li>
                  <li class='outer2'> Two?
                    <div>
                      <ul class='inner2'><li class='inner22'></li></ul>
                    </div>
                  </li>
                </ul>
                TROUBLE STARTS
                <div data-elastic-include>
                  !! THIS SHOULD BE INCLUDED !!
                </div> <!-- end elastic include -->
              </div>
              !! THIS SHOULD BE EXCLUDED
            </div>
          </body>
        HTML
      end

      it 'should return expected document body' do
        expect(document_body).to eq('!! THIS SHOULD BE INCLUDED !!')
      end
    end

    # See https://discuss.elastic.co/t/little-help-needed-with-crawler-content-exclusion-7-14/291154 for an example
    context 'when using a top-level wrapping tag to set the default behavior' do
      let(:html) do
        <<-HTML
          <body>
            <span data-elastic-exclude>
              <menu>menu</menu>
              <main data-elastic-include>content</main>
              <footer>footer</footer>
            </span>
          </body>
        HTML
      end

      it 'should return expected document body' do
        expect(document_body).to eq('content')
      end
    end

    # See https://discuss.elastic.co/t/little-help-needed-with-crawler-content-exclusion-7-14/291154 for an example
    context 'when using body attributes to set the default behavior' do
      let(:html) do
        <<-HTML
          <body data-elastic-exclude>
            <menu>menu</menu>
            <main data-elastic-include>content</main>
            <footer>footer</footer>
          </body>
        HTML
      end

      it 'should return expected document body' do
        expect(document_body).to eq('content')
      end
    end
  end

  describe '.transform' do
    let(:doc) { Jsoup.parse(html) }
    let(:html) do
      <<-HTML
        <body>
          test1
          <div data-elastic-exclude>
            <a href="http://elastic.co">Elastic</a>
          </div>
          test3
        </body>
      HTML
    end

    it 'does not modify doc' do
      body = doc.body
      transformed_body = described_class.transform(body)
      body_text = Crawler::ContentEngine::Utils.node_descendant_text(transformed_body)
      expect(body_text).to eq('test1 test3')

      link = doc.selectFirst('a')
      expect(link).to_not be_nil
      expect(link.text).to eq('Elastic')
    end
  end
end
