// Dessine le blason du site (tools/media/logo-site.svg, copie de dernier-rempart.eu)
// en PNG transparent, à grande taille : node tools/media/render_logo.js sortie.png [hauteur]
// make_media.py s'en sert pour fabriquer logo.tga et minimap.tga.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const out = process.argv[2];
  const h = parseInt(process.argv[3] || '1024', 10);
  const w = Math.round(h * 48 / 56);
  const svg = fs.readFileSync(path.join(__dirname, 'logo-site.svg'), 'utf8')
    .replace('<svg ', `<svg width="${w}" height="${h}" `);
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: w, height: h } });
  await p.setContent(`<!doctype html><body style="margin:0;background:transparent">${svg}</body>`);
  await p.screenshot({ path: out, omitBackground: true });
  await b.close();
})();
