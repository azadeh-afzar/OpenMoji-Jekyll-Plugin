# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Jekyll::Emoji) do
  Jekyll.logger.log_level = :error

  let(:config_overrides) { {} }
  let(:configs) do
    Jekyll.configuration(
      config_overrides.merge(
        "skip_config_files" => false,
        "collections"       => { "docs" => { "output" => true }, "secret" => {} },
        "source"            => fixtures_dir,
        "destination"       => fixtures_dir("_site")
      )
    )
  end
  let(:emoji)       { described_class }
  let(:site)        { Jekyll::Site.new(configs) }
  let(:default_src) { "https://cdn.jsdelivr.net/gh/azadeh-afzar/OpenMoji-Jekyll-Plugin@latest" }
  let(:default_asset_path) { "/images/color/svg" }
  let(:default_directory) { "/emoji" }
  let(:default_file_name) { "/:file_name" }
  let(:result) do
    <<-STR.strip
    <img class="emoji" title="+1" alt="👍️" src="#{default_src}#{default_asset_path}/1f44d.svg" height="20" width="20">
    STR
  end

  let(:posts)        { site.posts.docs }
  let(:basic_post)   { find_by_title(posts, "Refactor") }
  let(:complex_post) { find_by_title(posts, "Code Block") }

  let(:pages) { site.pages }
  let(:index) { site.pages.find { |page| page["title"] == "OpenMoji" } }
  let(:minified) { site.pages.find { |page| page["title"] == "OpenMoji Minified" } }

  # plain_* denote pages that generate markup containing body tags without any attribute.
  # For example, <body>Hello World!</body>
  let(:plain_index) { site.pages.find { |page| page["title"] == "Plain OpenMoji" } }
  let(:plain_minified) { site.pages.find { |page| page["title"] == "Plain OpenMoji Minified" } }

  let(:multiline_body_tag) { site.pages.find { |page| page["title"] == "Multi-line Body Tag" } }

  let(:basic_doc) { find_by_title(site.collections["docs"].docs, "File") }
  let(:doc_with_liquid) { find_by_title(site.collections["docs"].docs, "With Liquid") }
  let(:txt_doc) { find_by_title(site.collections["docs"].docs, "Don't Touch Me") }

  def para(content)
    "<p>#{content}</p>\n"
  end

  before(:each) do
    site.reset
    site.read
    (site.pages + posts + site.docs_to_write).each { |p| p.content.strip! }
    site.render
  end

  it "creates a filter" do
    expect(emoji.filters[default_src]).to be_a(HTML::Pipeline)
  end

  it "has a default source" do
    expect(emoji.emoji_src_root).to eql(default_src)
  end

  it "correctly replaces the emoji with the img in posts" do
    expect(basic_post.output).to eql(para(result))
  end

  it "doesn't replace emoji in a code block" do
    expect(complex_post.output).to include(
      "<span class=\"s2\">\":smile: every day\"</span>"
    )
    expect(complex_post.output).to include(result)
  end

  it "correctly replaces the emoji with the img in pages" do
    expect(index.output).to include(para(result))
  end

  it "correctly replaces the emoji with the img in collection documents" do
    expect(basic_doc.output).to eql(para(result))
  end

  it "leaves non-HTML files alone" do
    expect(txt_doc.output).to eql(":thumbs_up:")
  end

  it "does not replace the emoji if the collection document is not to be output" do
    expect(site.collections["secret"].docs.first.output).to eql(para(":thumbs_up:"))
  end

  it "does not mangle liquid templates" do
    expect(doc_with_liquid.output).to eql(
      para("#{result} <a href=\"/docs/with_liquid.html\">_docs/with_liquid.md</a>")
    )
  end

  it "does not mangle layouts" do
    expect(index.output).to eql(fixture("index.html"))
    expect(minified.output).to eql(fixture("minified_index.html"))
  end

  it "works with simple body tags without any attributes" do
    expect(plain_index.output).to eql(fixture("index_without_body_attributes.html"))
    expect(plain_minified.output).to eql(fixture("minified_index_without_body_attributes.html"))
  end

  it "works with HTML body tag markup across multiple lines" do
    expect(multiline_body_tag.output).to eql(fixture("multiline_body_tag.html"))
  end

  context "with a different emoji img_attrs" do
    let(:emoji_class) { "openmoji" }
    let(:config_overrides) do
      {
        "emoji" => { "img_attrs" => { "class" => emoji_class } },
      }
    end

    it "fetches the custom img_attrs from the config" do
      expect(emoji.emoji_attributes(site.config)[:class]).to eql(emoji_class)
    end

    it "respects the new class when emojifying" do
      expect(basic_post.output).to eql(para(result.sub("class: \"emoji\"",
                                                       "class: #{emoji_class}")))
    end
  end

  context "with a different base for jekyll-openmoji" do
    let(:emoji_src_root) { "http://mine.club" }
    let(:config_overrides) do
      {
        "emoji" => { "src" => emoji_src_root, "img_attrs" => { "class" => "emoji" } },
      }
    end

    it "fetches the custom base from the config" do
      expect(emoji.emoji_src_root(site.config)).to eql(emoji_src_root)
    end

    it "respects the new base when emojifying" do
      expect(basic_post.output).to eql(para(result.sub("#{default_src}#{default_asset_path}",
                                                       emoji_src_root + default_directory.to_s)))
    end
  end

  context "with the ASSET_HOST_URL environment variable set" do
    let(:asset_host_url)       { "https://assets.github.vm" }
    let(:default_src_from_env) { "#{asset_host_url}#{default_asset_path}" }

    before(:each) { ENV["ASSET_HOST_URL"] = asset_host_url }
    after(:each) { ENV.delete("ASSET_HOST_URL") }

    it "has the correct default source when ASSET_HOST_URL is set" do
      expect(emoji.emoji_src_root + default_asset_path).to eql(default_src_from_env)
    end

    it "trims a trailing / if necessary" do
      ENV["ASSET_HOST_URL"] = "#{asset_host_url}/"

      expect(emoji.emoji_src_root).to eql(asset_host_url)
    end

    it "falls back to using the default if ASSET_HOST_URL is empty" do
      ENV["ASSET_HOST_URL"] = ""
      expect(emoji.emoji_src_root).to eql(default_src)
    end
  end
end
