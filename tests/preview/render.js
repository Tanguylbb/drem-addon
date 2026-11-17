// Fait des images des fichiers JSON écrits par tests/preview.lua.
//   node tests/preview/render.js <dossier des json> <dossier Media>
// Contrôle aussi la mise en page : textes tronqués, textes qui se chevauchent.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const dir = process.argv[2];
const media = process.argv[3];
const rgba = (c, a) => c ? `rgba(${Math.round(c[0] * 255)},${Math.round(c[1] * 255)},${Math.round(c[2] * 255)},${(c[3] ?? 1) * (a ?? 1)})` : 'transparent';

function escapeHtml(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

// Les codes de couleur du jeu : |cffRRGGBB ... |r, les icônes |T...|t et les liens |H...|h[...]|h.
function wow(text) {
  const parts = text.split(/(\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t|\|H[^|]*\|h|\|h)/);
  let out = '', open = 0;
  for (const p of parts) {
    if (/^\|c[0-9a-fA-F]{8}$/.test(p)) { out += `<span style="color:#${p.slice(4)}">`; open++; }
    else if (p === '|r') { if (open) { out += '</span>'; open--; } }
    else if (/^\|T/.test(p)) out += '<i class="inl"></i>';
    else if (/^\|H/.test(p) || p === '|h') { /* le lien : on garde seulement son texte */ }
    else out += escapeHtml(p);
  }
  return out + '</span>'.repeat(open);
}

const dataUri = {};
function png(name) {
  if (dataUri[name]) return dataUri[name];
  const f = path.join(dir, 'media', name + '.png');
  if (!fs.existsSync(f)) return null;
  dataUri[name] = 'data:image/png;base64,' + fs.readFileSync(f).toString('base64');
  return dataUri[name];
}

function page(data) {
  const frames = data.items.filter(i => i.k === 'frame');
  const byFrame = {};
  for (const it of data.items) if (it.k !== 'frame') (byFrame[it.f] = byFrame[it.f] || []).push(it);
  frames.sort((a, b) => (a.lv - b.lv) || (a.id - b.id));
  let html = '';
  for (const fr of frames) {
    const list = (byFrame[fr.id] || []).sort((a, b) => (a.layer - b.layer) || (a.sub - b.sub) || (a.order - b.order));
    for (const it of list) {
      const box = `left:${it.l}px;top:${it.t}px;width:${it.w}px;height:${it.h}px;`;
      if (it.k === 'tex') {
        let st = '';
        if (it.color) st = `background:${rgba(it.color)};`;
        else if (it.grad) {
          const g = it.grad;
          st = g.orient === 'HORIZONTAL' ? `background:linear-gradient(to right,${rgba(g.from)},${rgba(g.to)});`
            : `background:linear-gradient(to bottom,${rgba(g.to)},${rgba(g.from)});`;
        } else if (it.img) {
          const m = it.img.match(/Media\\([A-Za-z_0-9]+)$/);
          if (m && png(m[1])) {
            const u = png(m[1]);
            if (it.vertex) st = `background:${rgba(it.vertex)};-webkit-mask:url(${u}) center/contain no-repeat;mask:url(${u}) center/contain no-repeat;`;
            else st = `background:url(${u}) center/contain no-repeat;`;
          } else if (/CheckBox-Check/.test(it.img)) {
            st = 'background:none;color:#F6D55A;font:bold 16px sans-serif;display:flex;align-items:center;justify-content:center;';
            html += `<div class="r" style="${box}${st}">✓</div>`;
            continue;
          } else {
            const label = (it.img.split(/[\\/]/).pop() || '?').slice(0, 10);
            st = `background:linear-gradient(#5a6b8c,#2c3850);color:#cfd8ea;font:9px sans-serif;display:flex;align-items:center;justify-content:center;overflow:hidden;`;
            html += `<div class="r" style="${box}${st}">${escapeHtml(label)}</div>`;
            continue;
          }
        } else continue;
        html += `<div class="r" style="${box}${st}"></div>`;
      } else if (it.k === 'text') {
        if (!it.text) continue;
        const brand = /Marcellus/.test(it.font);
        const justify = it.just === 'CENTER' ? 'center' : (it.just === 'RIGHT' ? 'flex-end' : 'flex-start');
        const align = it.jv === 'TOP' ? 'flex-start' : (it.jv === 'BOTTOM' ? 'flex-end' : 'center');
        const wrap = it.wrap ? 'white-space:normal;' : 'white-space:nowrap;';
        const width = it.autow ? 'min-width:' + it.w + 'px;' : 'width:' + it.w + 'px;';
        const height = (it.wrap && !it.hset) ? 'min-height:' + it.h + 'px;overflow:visible;' : 'height:' + it.h + 'px;';
        html += `<div class="t${it.autow ? ' auto' : ''}" data-w="${it.w}" data-h="${it.h}" style="left:${it.l}px;top:${it.t}px;${width}${height}display:flex;justify-content:${justify};align-items:${align};text-align:${it.just === 'CENTER' ? 'center' : it.just === 'RIGHT' ? 'right' : 'left'};font-size:${it.size}px;color:${rgba(it.tc)};${wrap}${brand ? "font-family:'Marcellus',serif;" : ''}"><span>${wow(it.text)}</span></div>`;
      }
    }
  }
  return `<!doctype html><meta charset="utf-8"><style>
body{margin:0;background:#0b0b0b}
#c{position:relative;width:${data.w}px;height:${data.h}px;overflow:hidden;font-family:'Liberation Sans','Arial',sans-serif;letter-spacing:.03em;
 background:radial-gradient(ellipse at 18% 28%,#27362a 0%,transparent 55%),radial-gradient(ellipse at 88% 72%,#3a2a1a 0%,transparent 55%),#0b0b0b}
.r,.t{position:absolute;box-sizing:border-box}
.t{overflow:hidden;line-height:1.15;text-shadow:1px -1px 0 rgba(0,0,0,.9);}
.t span{overflow:hidden;text-overflow:ellipsis;max-width:100%}
.t.auto{overflow:visible}.t.auto span{overflow:visible;max-width:none}
.inl{display:inline-block;width:1em;height:1em;background:#8a8f9c;margin-right:2px;vertical-align:-2px}
@font-face{font-family:Marcellus;src:url('file://${path.resolve(media)}/Fonts/Marcellus-Regular.ttf')}
</style><div id="c">${html}</div>`;
}

(async () => {
  fs.mkdirSync(path.join(dir, 'media'), { recursive: true });
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1000, height: 740 } });
  let problems = 0;
  for (const f of fs.readdirSync(dir).filter(n => n.endsWith('.json')).sort()) {
    const data = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
    const file = path.join(dir, f.replace('.json', '.html'));
    fs.writeFileSync(file, page(data));
    await p.goto('file://' + path.resolve(file));
    await p.waitForTimeout(150);
    const report = await p.evaluate(() => {
      const out = [];
      const texts = [...document.querySelectorAll('.t')];
      const rects = [];
      for (const t of texts) {
        const s = t.querySelector('span');
        if (!s) continue;
        const txt = t.textContent.trim();
        if (!t.classList.contains('auto') && s.scrollWidth > s.clientWidth + 1 && getComputedStyle(t).whiteSpace === 'nowrap') {
          out.push('(coupé par …) « ' + txt.slice(0, 50) + ' » (' + s.scrollWidth + ' > ' + s.clientWidth + ')');
        }
        if (getComputedStyle(t).whiteSpace !== 'nowrap' && t.scrollHeight > t.clientHeight + 2) {
          out.push('texte rogné en hauteur : « ' + txt.slice(0, 50) + ' »');
        }
        const r = document.createRange(); r.selectNodeContents(s);
        const b = r.getBoundingClientRect();
        const tb = t.getBoundingClientRect();
        const auto = t.classList.contains('auto');
        // Un texte dans une zone fixe est coupé par « … » : seule la partie visible compte.
        let l = b.left, rr = b.right;
        if (!auto) { l = Math.max(l, tb.left); rr = Math.min(rr, tb.right); }
        // La police du jeu est plus large que celle de l'aperçu : on grossit le texte
        // de 12 % du côté libre, pour que « presque en contact » compte comme chevauchement.
        const grow = (rr - l) * 0.12;
        const right = getComputedStyle(t).justifyContent === 'flex-end';
        let nl = right ? l - grow : l, nr = right ? rr : rr + grow;
        if (!auto) { nl = Math.max(nl, tb.left); nr = Math.min(nr, tb.right); } // une zone fixe coupe, elle ne déborde pas
        if (rr - l > 0 && b.height > 0) rects.push({ txt, l: nl, t: b.top, r: nr, b: b.bottom });
      }
      for (let i = 0; i < rects.length; i++) for (let j = i + 1; j < rects.length; j++) {
        const a = rects[i], c = rects[j];
        const w = Math.min(a.r, c.r) - Math.max(a.l, c.l), h = Math.min(a.b, c.b) - Math.max(a.t, c.t);
        if (w > 3 && h > 4) {
          const small = Math.min((a.r - a.l) * (a.b - a.t), (c.r - c.l) * (c.b - c.t));
          if (w * h > 0.25 * small) out.push('se chevauchent : « ' + a.txt.slice(0, 30) + ' » / « ' + c.txt.slice(0, 30) + ' »');
        }
      }
      return out;
    });
    await p.screenshot({ path: path.join(dir, f.replace('.json', '.png')) });
    console.log(f.replace('.json', ''), report.length ? '' : 'rien à signaler');
    for (const r of report.slice(0, 14)) console.log('   ' + r);
    problems += report.filter(r => !r.startsWith('(coupé')).length;
  }
  await b.close();
  console.log(problems + ' problème(s) (hors textes coupés par …)');
  if (problems) process.exitCode = 1;
})();
