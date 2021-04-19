import { ContentWriter } from 'data/content/writers/writer';
import { defaultWriterContext } from 'data/content/writers/context';
import { HtmlParser } from 'data/content/writers/html';

const exampleUnsupportedContent = require('./example_unsupported_content.json');
const exampleMalformedContent = require('./example_malformed_content.json');
const exampleContent = require('./example_content.json');

const parse = (content: any, context = defaultWriterContext()) =>
  new ContentWriter().render(context, content, new HtmlParser());

describe('parser', () => {
  it('renders well-formed content properly', () => {
    const htmlString = parse(exampleContent);
    expect(htmlString).toContain('<h3>Introduction</h3>');
    expect(htmlString).toMatch(new RegExp('<img.* src="https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg/480px-Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg"/>'));
    expect(htmlString).toContain('<p>The American colonials proclaimed &quot;no taxation without representation');
    expect(htmlString).toContain('<a class="internal-link" href="#">Page Two</a>');
    expect(htmlString).toContain('<a class="external-link" href="https://en.wikipedia.org/wiki/Stamp_Act_Congress" target="_blank">Stamp Act Congress</a>');
    expect(htmlString).toContain('<h3>1651–1748: Early seeds</h3>');
    expect(htmlString).toContain('<ol><li>one</li>\n<li><em>two</em></li>\n<li><em><strong>three</strong></em></li>\n</ol>');
    expect(htmlString).toContain('<ul><li>alpha</li>\n<li>beta</li>\n<li>gamma</li>\n</ul>');
    expect(htmlString).toMatch(new RegExp('<iframe.* id="fhdCslFcKFU".* src="https://www.youtube.com/embed/fhdCslFcKFU"></iframe>'));
    expect(htmlString).toMatch(new RegExp('<pre><code.*>import fresh-pots\n</code></pre>'));
  });

  it('renders internal link with context', () => {
    const htmlString = parse(exampleContent, defaultWriterContext({sectionSlug: "some_section"}));
    expect(htmlString).toContain('<a class="internal-link" href="/sections/some_section/page/page_two">Page Two</a>');
  });

  it('renders malformed page gracefully', () => {
    const htmlString = parse(exampleMalformedContent);
    expect(htmlString).toContain('<h3>Introduction</h3>');
    expect(htmlString).toContain('<div class=\"content invalid\">Content element is invalid');
  });
  it('renders unsupported content gracefully', () => {
    const htmlString = parse(exampleUnsupportedContent);
    expect(htmlString).toContain('<h3>Introduction</h3>');
    expect(htmlString).toContain('<div class=\"content invalid\">Content element is invalid');
  });
});
