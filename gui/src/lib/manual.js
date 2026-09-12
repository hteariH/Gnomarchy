// Manual page naming and search. Pure, so it is tested under Node; the page
// module supplies the file contents.

export function pageTitle(fileName) {
  const base = fileName.replace(/\.md$/, '');
  const separator = base.indexOf('-');
  if (separator === -1) return base;
  const number = base.slice(0, separator);
  const slug = base.slice(separator + 1).replace(/-/g, ' ');
  return `${number}  ${slug.charAt(0).toUpperCase()}${slug.slice(1)}`;
}

// Full-text, the way `gnomarchy manual --grep` is, rather than title-only:
// the page you want is usually identified by a word inside it.
export function searchPages(pages, query) {
  const needle = query.trim().toLowerCase();
  if (needle === '') return pages.map((page) => ({ page, snippet: '' }));

  const results = [];
  for (const page of pages) {
    if (page.title.toLowerCase().includes(needle)) {
      results.push({ page, snippet: '' });
      continue;
    }
    const line = page.text
      .split('\n')
      .find((candidate) => candidate.toLowerCase().includes(needle));
    if (line !== undefined) results.push({ page, snippet: line.trim() });
  }
  return results;
}
