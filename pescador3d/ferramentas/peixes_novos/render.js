const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ deviceScaleFactor: 2, viewport: { width: 700, height: 800 } });
  await p.goto('file://' + process.argv[2]);
  for (const id of ['cioba_lado','boi_lado','lua_lado','cioba_cima','boi_cima','lua_cima']) {
    const el = await p.$('#' + id);
    await el.screenshot({ path: `${process.argv[3]}/${id}.png`, omitBackground: true });
  }
  await b.close();
})();
