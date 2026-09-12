// Markdown -> Pango markup, for the manual pages only.
//
// The supported subset is not a guess: across the 17 pages there are 17 '#',
// 60 '##', 2 '###', 26 fenced code blocks, 41 list items, 20 bold spans and
// 121 inline code spans, and zero tables, links, images or blockquotes.
// unsupported() lets CI keep it that way, so a page that grows a table fails
// the build instead of rendering as "| a | b |".
//
// Pure: no gi:// imports, so this runs under Node in the unit tests.

export function escapePango(text) {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Inline code is extracted before any other formatting so that markdown
// characters inside it stay literal, then restored at the end. The
// placeholders use Unicode private-use characters, which cannot occur in a
// manual page, so no real text can be mistaken for one.
const CODE_OPEN = '';
const CODE_CLOSE = '';
const CODE_PLACEHOLDER = new RegExp(`${CODE_OPEN}(\\d+)${CODE_CLOSE}`, 'g');

function inline(text) {
  const codes = [];
  const withPlaceholders = text.replace(/`([^`]*)`/g, (_, code) => {
    codes.push(code);
    return `${CODE_OPEN}${codes.length - 1}${CODE_CLOSE}`;
  });

  const out = escapePango(withPlaceholders)
    .replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>')
    .replace(/(^|[^*])\*([^*]+)\*/g, '$1<i>$2</i>');

  return out.replace(CODE_PLACEHOLDER, (_, i) => `<tt>${escapePango(codes[Number(i)])}</tt>`);
}

export function renderBlocks(md) {
  const lines = md.split('\n');
  const blocks = [];

  let paragraph = [];
  let list = null; // { type: 'ul' | 'ol', items: string[] }
  let fence = null; // string[] while inside a fenced block

  const flushParagraph = () => {
    if (paragraph.length > 0) {
      blocks.push({ type: 'p', markup: inline(paragraph.join(' ')) });
      paragraph = [];
    }
  };
  const flushList = () => {
    if (list !== null) {
      blocks.push({ type: list.type, markup: list.items.join('\n') });
      list = null;
    }
  };
  const flushAll = () => { flushParagraph(); flushList(); };

  for (const line of lines) {
    if (fence !== null) {
      if (line.startsWith('```')) {
        blocks.push({ type: 'code', markup: escapePango(fence.join('\n')) });
        fence = null;
      } else {
        fence.push(line);
      }
      continue;
    }

    if (line.startsWith('```')) { flushAll(); fence = []; continue; }

    if (line.trim() === '') { flushAll(); continue; }

    const heading = /^(#{1,3})\s+(.*)$/.exec(line);
    if (heading !== null) {
      flushAll();
      blocks.push({ type: `h${heading[1].length}`, markup: inline(heading[2].trim()) });
      continue;
    }

    const bullet = /^[-*]\s+(.*)$/.exec(line);
    if (bullet !== null) {
      flushParagraph();
      if (list === null || list.type !== 'ul') { flushList(); list = { type: 'ul', items: [] }; }
      list.items.push(`• ${inline(bullet[1])}`);
      continue;
    }

    const numbered = /^(\d+)\.\s+(.*)$/.exec(line);
    if (numbered !== null) {
      flushParagraph();
      if (list === null || list.type !== 'ol') { flushList(); list = { type: 'ol', items: [] }; }
      list.items.push(`${numbered[1]}. ${inline(numbered[2])}`);
      continue;
    }

    flushList();
    paragraph.push(line.trim());
  }

  if (fence !== null) blocks.push({ type: 'code', markup: escapePango(fence.join('\n')) });
  flushAll();
  return blocks;
}

export function unsupported(md) {
  const found = [];
  let inFence = false;

  md.split('\n').forEach((line, index) => {
    if (line.startsWith('```')) { inFence = !inFence; return; }
    if (inFence) return;

    const at = (kind) => found.push({ line: index + 1, kind });

    if (/^\s*\|.*\|\s*$/.test(line)) at('table');
    else if (/^\s*>/.test(line)) at('blockquote');
    else if (/!\[[^\]]*\]\([^)]*\)/.test(line)) at('image');
    else if (/\[[^\]]*\]\([^)]*\)/.test(line)) at('link');
  });

  return found;
}
