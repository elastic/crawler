#
#

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Crawler::ContentEngine::Markdown do
  let(:document) { org.jsoup.Jsoup.parse(html) }
  let(:body) { document.body }

  describe '.convert' do
    subject { described_class.convert(body) }

    context 'with headers' do
      let(:html) { '<h1>H1</h1><h2>H2</h2><h3>H3</h3><h4>H4</h4><h5>H5</h5><h6>H6</h6>' }

      it 'converts headers to markdown' do
        expect(subject).to eq("# H1\n\n## H2\n\n### H3\n\n#### H4\n\n##### H5\n\n###### H6")
      end
    end

    context 'with basic formatting' do
      let(:html) { '<p><strong>Strong</strong> <b>Bold</b> <em>Em</em> <i>Italic</i> <br> line break</p>' }

      it 'converts formatting tags to markdown' do
        expect(subject).to include('**Strong**')
        expect(subject).to include('**Bold**')
        expect(subject).to include('*Em*')
        expect(subject).to include('*Italic*')
        expect(subject).to include('line break')
      end
    end

    context 'with links' do
      let(:html) { '<a href="https://example.com">Example</a>' }

      it 'converts links to markdown' do
        expect(subject).to eq('[Example](https://example.com)')
      end

      context 'when href is missing' do
        let(:html) { '<a>Example</a>' }

        it 'handles missing href gracefully' do
          expect(subject).to eq('[Example]()')
        end
      end
    end

    context 'with lists' do
      context 'unordered lists' do
        let(:html) { '<ul><li>Item 1</li><li>Item 2</li></ul>' }

        it 'converts unordered lists to markdown' do
          expect(subject).to eq("* Item 1\n* Item 2")
        end
      end

      context 'ordered lists' do
        let(:html) { '<ol><li>Item 1</li><li>Item 2</li></ol>' }

        it 'converts ordered lists to markdown using numbers' do
          expect(subject).to eq("1. Item 1\n1. Item 2")
        end
      end
    end

    context 'with images' do
      let(:html) { '<img src="image.png" alt="An image">' }

      it 'converts images to markdown' do
        expect(subject).to eq('![An image](image.png)')
      end

      context 'when attributes are missing' do
        let(:html) { '<img>' }

        it 'handles missing attributes gracefully' do
          expect(subject).to eq('![]()')
        end
      end
    end

    context 'with code and pre' do
      it 'converts inline code' do
        expect(described_class.convert(org.jsoup.Jsoup.parse('<code>code block</code>').body)).to eq('`code block`')
      end

      it 'converts pre blocks' do
        expect(described_class.convert(org.jsoup.Jsoup.parse('<pre>some code</pre>').body)).to eq("```\nsome code\n```")
      end
    end

    context 'with nested elements' do
      let(:html) { '<div><h1>Title</h1><p>Text with <a href="/link">link</a> and <b>bold</b>.</p></div>' }

      it 'converts nested elements correctly' do
        expect(subject).to eq("# Title\n\nText with [link](/link) and **bold**.")
      end
    end

    context 'with non-content tags' do
      let(:html) do
        '<div>Content<script>...</script><style>...</style><object>...</object><svg>...</svg><video>...</video></div>'
      end

      it 'removes all non-content tags' do
        expect(subject).to eq('Content')
      end
    end

    context 'with multiple paragraphs' do
      let(:html) { '<p>Para 1</p><p>Para 2</p>' }

      it 'separates paragraphs with double newlines' do
        expect(subject).to eq("Para 1\n\nPara 2")
      end
    end

    context 'with deeply nested structure' do
      let(:html) do
        <<~HTML
                    <div>
                      <h1>Main Title</h1>
                      <p>Intro text with <b>bold</b> and <i>italic</i>.</p>
                      <ul>
                        <li>Item 1 with <a href="/1">link</a></li>
                        <li>Item 2 with <code>code</code></li>
                      </ul>
                      <pre>Preformatted
          block</pre>
                    </div>
        HTML
      end

      it 'converts complex structures correctly' do
        expect(subject).to include('# Main Title')
        expect(subject).to include('Intro text with **bold** and *italic*.')
        expect(subject).to include('* Item 1 with [link](/1)')
        expect(subject).to include('* Item 2 with `code`')
        expect(subject).to include('```')
        expect(subject).to include('Preformatted')
      end
    end

    context 'with mixed list types' do
      let(:html) { '<ul><li>UL</li></ul><ol><li>OL</li></ol>' }

      it 'handles switching between list types' do
        expect(subject).to include('* UL')
        expect(subject).to include('1. OL')
      end
    end

    context 'with nil input' do
      it 'returns an empty string' do
        expect(described_class.convert(nil)).to eq('')
      end
    end
  end
end
