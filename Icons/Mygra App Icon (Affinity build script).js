// Mygra 3.0 app icon as a layered Affinity document. Geometry and colours match AppIcon.icon
// (Assets/1-back-halo.svg, 2-middle-head.svg, 3-front-shoulders.svg on a 1024 x 1024 canvas). Creates a new document each run.
const { Document, NewDocumentOptions, FileExportOptions, FileExportArea } = require('/document.js');
const Nodes = require('/nodes.js');
const { ShapeRectangle, ShapeEllipse, ShapeCornerType } = require('/shapes.js');
const { Colour, Gradient } = require('/colours.js');
const { Rectangle, Transform, CurveBuilder, PolyCurve } = require('/geometry.js');
const { FillDescriptor, GradientFill, GradientFillType, BlendMode } = require('/fills.js');
const { DocumentCommand, AddChildNodesCommandBuilder } = require('/commands.js');
const { InsertionMode } = require('affinity:commands');
const { Selection } = require('/selections.js');
const { UnitType } = require('/units.js');

const DESK = '/Users/nickmolargik/Desktop/Mygra Icon (Claude)';
const log = (...a) => console.log(a.join(' '));
const o = NewDocumentOptions.createDefault();
o.units = UnitType.Pixel; o.width = 1024; o.height = 1024; o.dpi = 72; o.createArtboard = true; o.isTransparentBackground = true;
const doc = Document.createFromOptions(o);
const spread = doc.spreads.first;
const kids = n => { const out = []; for (const c of n.children) out.push(c); return out; };
const sel = n => Selection.create(doc, n);
const run = cmd => doc.executeCommand(cmd);
const rgba = hex => { const h = hex.replace('#', ''); return Colour.createRGBA8({ r: parseInt(h.slice(0, 2), 16), g: parseInt(h.slice(2, 4), 16), b: parseInt(h.slice(4, 6), 16), alpha: 255 }); };
const solid = hex => FillDescriptor.createSolid(rgba(hex));
const name = (n, s) => run(DocumentCommand.createSetDescription(sel(n), s));
function addTo(target, def, label) {
  const b = AddChildNodesCommandBuilder.create(); b.addNode(def); b.setInsertionTarget(target); b.setInsertionMode(InsertionMode.Inside_AtBack);
  const cmd = b.createCommand(false); run(cmd);
  const n = cmd.newNodes[0]; if (label) name(n, label); return n;
}
function settle(n, x, y) { const b = n.spreadBaseBox; if (Math.abs(b.x - x) > 0.01 || Math.abs(b.y - y) > 0.01) run(DocumentCommand.createTransform(sel(n), Transform.createTranslate(x - b.x, y - b.y))); return n; }
function vGradient(x, y, w, h, top, bottom) {
  const g = Gradient.create([{ position: 0, colour: rgba(top) }, { position: 1, colour: rgba(bottom) }]);
  const xf = Transform.createTranslate(x + w / 2, y).multiply(Transform.createRotate(Math.PI / 2)).multiply(Transform.createScale(h, h));
  return FillDescriptor.create(GradientFill.create(g, GradientFillType.Linear), true, xf, BlendMode.Normal, false);
}
function rect(target, label, x, y, w, h, fill, radius) {
  const shape = ShapeRectangle.create();
  if (radius) { shape.setAbsoluteSizes(true, w, h); shape.useSingleRadius = true; for (const c of [shape.topLeft, shape.topRight, shape.bottomLeft, shape.bottomRight]) { c.cornerType = ShapeCornerType.Round; c.setRadius(radius, w, h); } }
  return settle(addTo(target, Nodes.ShapeNodeDefinition.create(shape, new Rectangle(x, y, w, h), typeof fill === 'string' ? solid(fill) : fill, null, null, null), label), x, y);
}
function ellipse(target, label, cx, cy, r, hex) {
  return settle(addTo(target, Nodes.ShapeNodeDefinition.create(ShapeEllipse.create(), new Rectangle(cx - r, cy - r, 2 * r, 2 * r), solid(hex), null, null, null), label), cx - r, cy - r);
}
function group(target, label) { return addTo(target, Nodes.ContainerNodeDefinition.create(label), label); }
// Path helpers: every segment is a cubic; straight lines put their handles on the line.
function line(b, p, q) { b.addBezierXY(p[0] + (q[0] - p[0]) / 3, p[1] + (q[1] - p[1]) / 3, p[0] + 2 * (q[0] - p[0]) / 3, p[1] + 2 * (q[1] - p[1]) / 3, q[0], q[1]); return q; }
function arc(b, cx, cy, r, a0, a1) {
  const n = Math.ceil(Math.abs(a1 - a0) / (Math.PI / 2)), d = (a1 - a0) / n, k = 4 / 3 * Math.tan(d / 4);
  for (let i = 0; i < n; i++) { const s = a0 + i * d, e = s + d;
    b.addBezierXY(cx + r * (Math.cos(s) - k * Math.sin(s)), cy + r * (Math.sin(s) + k * Math.cos(s)), cx + r * (Math.cos(e) + k * Math.sin(e)), cy + r * (Math.sin(e) - k * Math.cos(e)), cx + r * Math.cos(e), cy + r * Math.sin(e)); }
  return [cx + r * Math.cos(a1), cy + r * Math.sin(a1)];
}
function quad(b, p, c, q) { b.addBezierXY(p[0] + 2 / 3 * (c[0] - p[0]), p[1] + 2 / 3 * (c[1] - p[1]), q[0] + 2 / 3 * (c[0] - q[0]), q[1] + 2 / 3 * (c[1] - q[1]), q[0], q[1]); return q; }
function path(target, label, hex, draw, box) {
  const b = new CurveBuilder(); draw(b); b.close();
  const pc = PolyCurve.create(); pc.addCurve(b.createCurve());
  const n = addTo(target, Nodes.PolyCurveNodeDefinition.create(pc, solid(hex), null, null, null), label);
  return box ? settle(n, box[0], box[1]) : n;
}
const RAD = Math.PI / 180;
// The artwork at (ox, oy): halo (8 segments, inner 172, outer 300, 7 degree gaps, one centred straight up), head, shoulders.
function artwork(ab, ox, oy) {
  const cx = ox + 512, cy = oy + 400;
  const halo = group(ab, 'Back: halo');
  for (let i = 0; i < 8; i++) {
    const a0 = (-90 - 22.5 + i * 45 + 3.5) * RAD, a1 = (-90 - 22.5 + (i + 1) * 45 - 3.5) * RAD;
    const n = path(halo, 'Segment ' + (i + 1), '#AEA7FF', b => {
      b.beginXY(cx + 300 * Math.cos(a0), cy + 300 * Math.sin(a0));
      let p = arc(b, cx, cy, 300, a0, a1);
      p = line(b, p, [cx + 172 * Math.cos(a1), cy + 172 * Math.sin(a1)]);
      arc(b, cx, cy, 172, a1, a0);
    });
    // place by the segment's true box (computed from its corner and arc extremes)
    const xs = [], ys = [];
    for (let t = 0; t <= 20; t++) { const a = a0 + (a1 - a0) * t / 20; for (const r of [172, 300]) { xs.push(cx + r * Math.cos(a)); ys.push(cy + r * Math.sin(a)); } }
    settle(n, Math.min(...xs), Math.min(...ys));
  }
  const head = group(ab, 'Middle: head');
  ellipse(head, 'Head', cx, cy, 150, '#6E60FF');
  const front = group(ab, 'Front: shoulders');
  path(front, 'Shoulders', '#6CB8F4', b => {
    let p = [ox + 232, oy + 850]; b.beginXY(p[0], p[1]);
    p = line(b, p, [ox + 232, oy + 790]);
    p = arc(b, ox + 512, oy + 790, 280, Math.PI, 2 * Math.PI);
    p = line(b, p, [ox + 792, oy + 850]);
    p = quad(b, p, [ox + 792, oy + 870], [ox + 772, oy + 870]);
    p = line(b, p, [ox + 252, oy + 870]);
    quad(b, p, [ox + 232, oy + 870], [ox + 232, oy + 850]);
  }, [ox + 232, oy + 510]);
}
const LIGHT = ['#FFFFFF', '#E9E8EF'], DARK = ['#34303D', '#121015'];
const boards = [
  { title: 'App Icon, light (preview)', x: 0, bg: LIGHT, r: 230 },
  { title: 'App Icon, dark (preview)', x: 1184, bg: DARK, r: 230 },
  { title: 'App Icon, square (full bleed)', x: 2368, bg: LIGHT, r: 0 },
  { title: 'Layers for Icon Composer (no background)', x: 3552, bg: null },
];
const first = kids(spread)[0];
for (const [i, b] of boards.entries()) {
  let ab = first;
  if (i > 0) {
    run(DocumentCommand.createAddArtboard(Nodes.ShapeNodeDefinition.create(ShapeRectangle.create(), new Rectangle(b.x, 0, 1024, 1024), null, null, null, null)));
    ab = kids(spread).find(k => { const bb = k.spreadBaseBox; return Math.abs(bb.x - b.x) < 0.5 && Math.abs(bb.width - 1024) < 0.5; });
  }
  name(ab, b.title);
  if (b.bg) rect(ab, 'Background', b.x, 0, 1024, 1024, vGradient(b.x, 0, 1024, 1024, b.bg[0], b.bg[1]), b.r || undefined);
  artwork(ab, b.x, 0);
}
doc.saveAs(DESK + '/Mygra App Icon.af');
const abs = []; for (const a of spread.artboards) abs.push(a);
let n = 0;
for (const a of abs) { try { doc.export(DESK + '/export/' + (a.description || 'artboard').replace(/[^A-Za-z0-9]+/g, '-') + '.png', FileExportOptions.createWithPresetName('PNG'), FileExportArea.createForArtboard(a)); n++; } catch (e) { log('export failed', String(e).slice(0, 120)); } }
log('built', abs.length, 'artboards, exported', n, 'uuid', doc.sessionUuid);
