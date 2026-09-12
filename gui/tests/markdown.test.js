import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderBlocks, unsupported, escapePango } from '../src/lib/markdown.js';

test('escapePango escapes the three markup characters', () => {
  assert.equal(escapePango('a & b < c > d'), 'a &amp; b &lt; c &gt; d');
});

test('renderBlocks classifies the heading levels', () => {
  const blocks = renderBlocks('# One\n\n## Two\n\n### Three\n');
  assert.deepEqual(blocks.map((b) => b.type), ['h1', 'h2', 'h3']);
  assert.equal(blocks[0].markup, 'One');
});

test('renderBlocks joins wrapped paragraph lines into one block', () => {
  const blocks = renderBlocks('alpha\nbeta\n\ngamma\n');
  assert.deepEqual(blocks, [
    { type: 'p', markup: 'alpha beta' },
    { type: 'p', markup: 'gamma' },
  ]);
});

test('renderBlocks keeps fenced code verbatim and unformatted', () => {
  const blocks = renderBlocks('```bash\ngnomarchy update\na **b** `c`\n```\n');
  assert.deepEqual(blocks, [
    { type: 'code', markup: 'gnomarchy update\na **b** `c`' },
  ]);
});

test('renderBlocks applies inline bold, italic and code', () => {
  const [block] = renderBlocks('a **b** and *i* and `c`\n');
  assert.equal(block.markup, 'a <b>b</b> and <i>i</i> and <tt>c</tt>');
});

test('renderBlocks escapes before applying inline markup', () => {
  const [block] = renderBlocks('use `<Super>k` & go\n');
  assert.equal(block.markup, 'use <tt>&lt;Super&gt;k</tt> &amp; go');
});

test('renderBlocks does not format inside inline code', () => {
  const [block] = renderBlocks('literal `a **b** c`\n');
  assert.equal(block.markup, 'literal <tt>a **b** c</tt>');
});

test('renderBlocks collects list items into one block', () => {
  const blocks = renderBlocks('- one\n- two\n\n1. first\n2. second\n');
  assert.deepEqual(blocks, [
    { type: 'ul', markup: '• one\n• two' },
    { type: 'ol', markup: '1. first\n2. second' },
  ]);
});

test('unsupported reports constructs the renderer cannot show', () => {
  const md = 'fine\n\n| a | b |\n\n> quote\n\n[text](url)\n\n![alt](img)\n';
  assert.deepEqual(unsupported(md), [
    { line: 3, kind: 'table' },
    { line: 5, kind: 'blockquote' },
    { line: 7, kind: 'link' },
    { line: 9, kind: 'image' },
  ]);
});

test('unsupported ignores anything inside a fenced code block', () => {
  assert.deepEqual(unsupported('```\n| a | b |\n> not a quote\n```\n'), []);
});

test('unsupported is empty for a document using only the supported subset', () => {
  const md = '# T\n\n## S\n\npara **b** `c`\n\n- item\n\n```\ncode\n```\n';
  assert.deepEqual(unsupported(md), []);
});
