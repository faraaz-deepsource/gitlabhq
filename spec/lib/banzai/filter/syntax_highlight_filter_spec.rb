# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::SyntaxHighlightFilter do
  include FilterSpecHelper

  shared_examples "XSS prevention" do |lang|
    it "escapes HTML tags" do
      # This is how a script tag inside a code block is presented to this filter
      # after Markdown rendering.
      result = filter(%{<pre lang="#{lang}"><code>&lt;script&gt;alert(1)&lt;/script&gt;</code></pre>})

      # `(1)` symbols are wrapped by lexer tags.
      expect(result.to_html).not_to match(%r{<script>alert.*<\/script>})

      # `<>` stands for lexer tags like <span ...>, not &lt;s above.
      expect(result.to_html).to match(%r{alert(<.*>)?\((<.*>)?1(<.*>)?\)})
    end
  end

  context "when no language is specified" do
    it "highlights as plaintext" do
      result = filter('<pre><code>def fun end</code></pre>')

      expect(result.to_html.delete("\n")).to eq('<div class="gl-relative markdown-code-block js-markdown-code"><pre lang="plaintext" class="code highlight js-syntax-highlight language-plaintext" data-canonical-lang="" v-pre="true"><code><span id="LC1" class="line" lang="plaintext">def fun end</span></code></pre><copy-code></copy-code></div>')
    end

    include_examples "XSS prevention", ""
  end

  context "when contains mermaid diagrams" do
    it "ignores mermaid blocks" do
      result = filter('<pre data-mermaid-style="display" lang="mermaid"><code class="js-render-mermaid">mermaid code</code></pre>')

      expect(result.to_html.delete("\n")).to eq('<div class="gl-relative markdown-code-block js-markdown-code"><pre data-mermaid-style="display" lang="mermaid" class="code highlight js-syntax-highlight language-mermaid" v-pre="true"><code class="js-render-mermaid"><span id="LC1" class="line" lang="mermaid">mermaid code</span></code></pre><copy-code></copy-code></div>')
    end
  end

  context "when <pre> contains multiple <code> tags" do
    it "ignores the block" do
      result = filter('<pre><code>one</code> and <code>two</code></pre>')

      expect(result.to_html).to eq('<pre><code>one</code> and <code>two</code></pre>')
    end
  end

  # This can happen with the following markdown
  #
  # <div>
  # <pre><code>
  # something
  #
  #     else
  # </code></pre>
  # </div>
  #
  # The blank line causes markdown to process `    else` as a code block.
  # Which could lead to an orphaned node being replaced and failing
  context "when <pre><code> is a child of <pre><code> which is a child of a div " do
    it "captures all text and doesn't fail trying to replace a node with no parent" do
      text = "<div>\n<pre><code>\nsomething\n<pre><code>else\n</code></pre></code></pre>\n</div>"
      result = filter(text)

      expect(result.to_html.delete("\n")).to eq('<div><div class="gl-relative markdown-code-block js-markdown-code"><pre lang="plaintext" class="code highlight js-syntax-highlight language-plaintext" data-canonical-lang="" v-pre="true"><code><span id="LC1" class="line" lang="plaintext"></span><span id="LC2" class="line" lang="plaintext">something</span><span id="LC3" class="line" lang="plaintext">else</span></code></pre><copy-code></copy-code></div></div>')
    end
  end

  context "when a valid language is specified" do
    it "highlights as that language" do
      result = filter('<pre lang="ruby"><code>def fun end</code></pre>')

      expect(result.to_html.delete("\n")).to eq('<div class="gl-relative markdown-code-block js-markdown-code"><pre lang="ruby" class="code highlight js-syntax-highlight language-ruby" v-pre="true"><code><span id="LC1" class="line" lang="ruby"><span class="k">def</span> <span class="nf">fun</span> <span class="k">end</span></span></code></pre><copy-code></copy-code></div>')
    end

    include_examples "XSS prevention", "ruby"
  end

  context "when an invalid language is specified" do
    it "highlights as plaintext" do
      result = filter('<pre lang="gnuplot"><code>This is a test</code></pre>')

      expect(result.to_html.delete("\n")).to eq('<div class="gl-relative markdown-code-block js-markdown-code"><pre lang="plaintext" class="code highlight js-syntax-highlight language-plaintext" data-canonical-lang="gnuplot" v-pre="true"><code><span id="LC1" class="line" lang="plaintext">This is a test</span></code></pre><copy-code></copy-code></div>')
    end

    include_examples "XSS prevention", "gnuplot"
  end

  context "languages that should be passed through" do
    let(:delimiter) { described_class::LANG_PARAMS_DELIMITER }
    let(:data_attr) { described_class::LANG_PARAMS_ATTR }

    %w(math mermaid plantuml suggestion).each do |lang|
      context "when #{lang} is specified" do
        it "highlights as plaintext but with the correct language attribute and class" do
          result = filter(%{<pre lang="#{lang}"><code>This is a test</code></pre>})

          expect(result.to_html.delete("\n")).to eq(%{<div class="gl-relative markdown-code-block js-markdown-code"><pre lang="#{lang}" class="code highlight js-syntax-highlight language-#{lang}" v-pre="true"><code><span id="LC1" class="line" lang="#{lang}">This is a test</span></code></pre><copy-code></copy-code></div>})
        end

        include_examples "XSS prevention", lang
      end

      context "when #{lang} has extra params" do
        let(:lang_params) { 'foo-bar-kux' }
        let(:xss_lang) { "#{lang} data-meta=\"foo-bar-kux\"&lt;script&gt;alert(1)&lt;/script&gt;" }

        it "includes data-lang-params tag with extra information" do
          result = filter(%{<pre lang="#{lang}" data-meta="#{lang_params}"><code>This is a test</code></pre>})

          expect(result.to_html.delete("\n")).to eq(%{<div class="gl-relative markdown-code-block js-markdown-code"><pre lang="#{lang}" class="code highlight js-syntax-highlight language-#{lang}" #{data_attr}="#{lang_params}" v-pre="true"><code><span id="LC1" class="line" lang="#{lang}">This is a test</span></code></pre><copy-code></copy-code></div>})
        end

        include_examples "XSS prevention", lang

        include_examples "XSS prevention",
                         "#{lang} data-meta=\"foo-bar-kux\"&lt;script&gt;alert(1)&lt;/script&gt;"

        include_examples "XSS prevention",
          "#{lang} data-meta=\"foo-bar-kux\"<script>alert(1)</script>"
      end
    end

    context 'when multiple param delimiters are used' do
      let(:lang) { 'suggestion' }
      let(:lang_params) { '-1+10' }

      let(:expected_result) do
        %{<div class="gl-relative markdown-code-block js-markdown-code"><pre lang="#{lang}" class="code highlight js-syntax-highlight language-#{lang}" #{data_attr}="#{lang_params} more-things" v-pre="true"><code><span id="LC1" class="line" lang="#{lang}">This is a test</span></code></pre><copy-code></copy-code></div>}
      end

      context 'when delimiter is space' do
        it 'delimits on the first appearance' do
          result = filter(%{<pre lang="#{lang}" data-meta="#{lang_params} more-things"><code>This is a test</code></pre>})

          expect(result.to_html.delete("\n")).to eq(expected_result)
        end
      end

      context 'when delimiter is colon' do
        it 'delimits on the first appearance' do
          result = filter(%{<pre lang="#{lang}#{delimiter}#{lang_params} more-things"><code>This is a test</code></pre>})

          expect(result.to_html.delete("\n")).to eq(expected_result)
        end
      end
    end
  end

  context "when sourcepos metadata is available" do
    it "includes it in the highlighted code block" do
      result = filter('<pre data-sourcepos="1:1-3:3"><code lang="plaintext">This is a test</code></pre>')

      expect(result.to_html.delete("\n")).to eq('<div class="gl-relative markdown-code-block js-markdown-code"><pre data-sourcepos="1:1-3:3" lang="plaintext" class="code highlight js-syntax-highlight language-plaintext" data-canonical-lang="" v-pre="true"><code lang="plaintext"><span id="LC1" class="line" lang="plaintext">This is a test</span></code></pre><copy-code></copy-code></div>')
    end

    it "escape sourcepos metadata to prevent XSS" do
      result = filter('<pre data-sourcepos="&#34;%22 href=&#34;x&#34;></pre><base href=http://unsafe-website.com/><pre x=&#34;"><code></code></pre>')

      expect(result.to_html.delete("\n")).to eq('<div class="gl-relative markdown-code-block js-markdown-code"><pre data-sourcepos=\'"%22 href="x"&gt;&lt;/pre&gt;&lt;base href=http://unsafe-website.com/&gt;&lt;pre x="\' lang="plaintext" class="code highlight js-syntax-highlight language-plaintext" data-canonical-lang="" v-pre="true"><code></code></pre><copy-code></copy-code></div>')
    end
  end

  context "when Rouge lexing fails" do
    before do
      allow_next_instance_of(Rouge::Lexers::Ruby) do |instance|
        allow(instance).to receive(:stream_tokens).and_raise(StandardError)
      end
    end

    it "highlights as plaintext" do
      result = filter('<pre lang="ruby"><code>This is a test</code></pre>')

      expect(result.to_html.delete("\n")).to eq('<div class="gl-relative markdown-code-block js-markdown-code"><pre lang="" class="code highlight js-syntax-highlight" data-canonical-lang="ruby" v-pre="true"><code><span id="LC1" class="line" lang="">This is a test</span></code></pre><copy-code></copy-code></div>')
    end

    include_examples "XSS prevention", "ruby"
  end

  context "when Rouge lexing fails after a retry" do
    before do
      allow_next_instance_of(Rouge::Lexers::PlainText) do |instance|
        allow(instance).to receive(:stream_tokens).and_raise(StandardError)
      end
    end

    it "does not add highlighting classes" do
      result = filter('<pre><code>This is a test</code></pre>')

      expect(result.to_html).to eq('<pre><code>This is a test</code></pre>')
    end

    include_examples "XSS prevention", "ruby"
  end

  it_behaves_like "filter timeout" do
    let(:text) { '<pre lang="ruby"><code>def fun end</code></pre>' }
  end
end
