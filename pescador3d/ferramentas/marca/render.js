const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1800, height: 820 }, deviceScaleFactor: 1 });
  await p.goto('file://' + __dirname + '/icones.html');
  await p.waitForTimeout(500);
  await p.screenshot({ path: 'previa_nomes_icones.png', fullPage: true });
  for (const id of ['i1', 'i2', 'i3']) {
    const svg = await p.$eval('#' + id, e => e.outerHTML);
    const q = await b.newPage({ viewport: { width: 512, height: 512 } });
    await q.setContent('<html><body style="margin:0;background:transparent">' + svg.replace('<svg ', '<svg width="512" height="512" ') + '</body></html>');
    await q.screenshot({ path: 'icone_' + id + '.png', omitBackground: true, clip: { x: 0, y: 0, width: 512, height: 512 } });
  }
  await b.close();
})();
