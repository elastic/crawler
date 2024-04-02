require 'spec_helper'

describe Faux::Element::AtomFeed do
  let(:site) { Class.new(Faux::Base) }

  def app
    site
  end

  it 'should return 200 by default for atom feed' do
    site.atom_feed '/feed'

    get '/feed'
    expect(last_response.status).to eq 200
  end

  it 'should return `text/xml` content type by default' do
    site.atom_feed '/feed'

    get '/feed'
    expect(last_response.content_type).to eq 'text/xml'
  end

  it 'should render empty atom feed with basic fields' do
    site.atom_feed '/feed'

    get '/feed'
    expect(last_response.body).to match 'http://www.w3.org/2005/Atom'
  end

  it 'should accept one or more Entry block' do
    site.atom_feed '/feed' do
      entry do
        link_to '/foo'
      end

      entry do
        link_to '/bar'
      end
    end

    get '/feed'
    expect(last_response.body).to match '/foo'
    expect(last_response.body).to match '/bar'
  end

  it 'should accept multiple tags insde Entry block' do
    site.atom_feed '/feed' do
      entry do
        link_to '/foo'
        link_to '/wow'
      end

      entry do
        link_to '/bar'
      end
    end

    get '/feed'
    expect(last_response.body.scan('<link').count).to eq 3
    expect(last_response.body).to match '/foo'
    expect(last_response.body).to match '/wow'
    expect(last_response.body).to match '/bar'
  end

  it 'should create html content tag inside Entry block' do
    site.atom_feed '/feed' do
      entry do
        html_content '<p>Working</p>'
      end
    end

    get '/feed'
    expect(last_response.body).to match '<content type=\"html\">&lt;p&gt;Working&lt;/p&gt;</content>'
  end

  it 'should accept any custom tag' do
    site.atom_feed '/feed' do
      entry do
        title 'New Post'
        link_to '/wow'
      end

      entry do
        title 'Another Post'
        link_to '/bar'
      end
    end

    get '/feed'
    expect(last_response.body).to match '<title>New Post</title>'
    expect(last_response.body).to match '/wow'
    expect(last_response.body).to match '<title>Another Post</title>'
    expect(last_response.body).to match '/bar'
    expect(last_response.body.scan('<link').count).to eq 2
  end

end
