'use strict';

window.printKingdomSheet = function (payload) {
  const sheet = JSON.parse(payload);
  const opener = document.activeElement;
  const frame = document.createElement('iframe');
  frame.title = 'Printable kingdom setup';
  frame.style.cssText = 'position:fixed;inset:0;width:100%;height:100%;border:0;z-index:2147483647;background:white';
  document.body.append(frame);
  const printed = frame.contentWindow;
  const page = frame.contentDocument;
  if (!printed || !page) {
    frame.remove();
    return false;
  }

  page.title = sheet.title;
  page.documentElement.lang = 'en';
  const style = page.createElement('style');
  style.textContent = `
    @page { margin: 15mm; }
    body { color: #111; font: 11pt system-ui, sans-serif; line-height: 1.35; }
    .sheet { max-width: 52rem; margin: 30px auto; padding: 0 22px; }
    .toolbar { display: flex; justify-content: flex-end; gap: 10px; padding: 12px 22px; border-bottom: 1px solid #ddd; }
    button { padding: 7px 16px; font: inherit; cursor: pointer; }
    h1 { margin: 0 0 4pt; font-size: 23pt; }
    h2 { font-size: 14pt; margin: 16pt 0 4pt; break-after: avoid; }
    p { margin: 0 0 8pt; }
    ul, ol { padding-left: 22pt; margin: 0; }
    li { padding: 2pt 0; break-inside: avoid; }
    .piles { columns: 2; column-gap: 22pt; }
    @media (max-width: 480px) { .piles { columns: 1; } }
    @media print {
      .toolbar { display: none; }
      .sheet { max-width: none; margin: 0; padding: 0; }
    }
  `;
  page.head.append(style);

  function add(parent, tag, text) {
    const element = page.createElement(tag);
    element.textContent = text;
    parent.append(element);
    return element;
  }

  const close = () => {
    frame.remove();
    if (opener?.isConnected) opener.focus();
  };
  const toolbar = add(page.body, 'div', '');
  toolbar.className = 'toolbar';
  const print = add(toolbar, 'button', 'Print');
  print.addEventListener('click', () => printed.print());
  add(toolbar, 'button', 'Close').addEventListener('click', close);
  printed.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') close();
  });

  const content = add(page.body, 'main', '');
  content.className = 'sheet';
  add(content, 'h1', sheet.title);
  add(content, 'p', sheet.subtitle);
  for (const [heading, items, ordered] of sheet.sections) {
    if (!items.length) continue;
    add(content, 'h2', heading);
    const list = add(content, ordered ? 'ol' : 'ul', '');
    if (ordered) list.className = 'piles';
    for (const item of items) add(list, 'li', item);
  }

  print.focus();
  return true;
};
