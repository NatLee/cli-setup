// Configure Terminal.app's default/startup profile — managed by mac-zsh-setup
//   osascript -l JavaScript terminal-app.js [fontPostScriptName|-] [prefsDomain]
//   ("-" = leave the font alone)
//
// • Home / End are sent to the shell (instead of scrolling the window)
// • Font is switched to Hack Nerd Font Mono, keeping the current size
// Uses only Foundation (no GUI scripting / Automation permission), so it also works over SSH.
// Terminal.app must be restarted to pick up the change.

ObjC.import('Foundation');

// NSKeyedArchiver blob of an NSFont (SFMono-Regular, 16pt) used when a profile has no Font yet.
const FONT_TEMPLATE =
  'YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9iamVjdHMSAAGGoF8QD05TS2V5ZWRBcmNoaXZlctEICVRyb290gAGkCwwVFlUkbnVsbNQNDg8QERITFFZOU1NpemVYTlNmRmxhZ3NWTlNOYW1lViRjbGFzcyNAMAAAAAAAABAQgAKAA15TRk1vbm8tUmVndWxhctIXGBkaWiRjbGFzc25hbWVYJGNsYXNzZXNWTlNGb250ohkbWE5TT2JqZWN0CBEaJCkyN0lMUVNYXmdud36FjpCSlKOos7zDxgAAAAAAAAEBAAAAAAAAABwAAAAAAAAAAAAAAAAAAADP';
const DEFAULT_SIZE_WITHOUT_FONT = 14;

function nil(o) { return o === undefined || o === null || (o.isNil && o.isNil()); }

// Rewrite the font name inside an NSKeyedArchiver NSFont blob (optionally the size too).
function retargetFont(data, fontName, size) {
  const err = Ref();
  const pl = $.NSPropertyListSerialization.propertyListWithDataOptionsFormatError(data, 2, null, err);
  if (nil(pl)) throw new Error('cannot parse font data');
  const objs = pl.objectForKey('$objects');
  let renamed = false;
  for (let i = 0; i < objs.count; i++) {
    const o = objs.objectAtIndex(i);
    if (o.isKindOfClass($.NSString) && ObjC.unwrap(o) !== '$null') {
      objs.replaceObjectAtIndexWithObject(i, $(fontName));
      renamed = true;
    } else if (size && o.isKindOfClass($.NSDictionary) && !nil(o.objectForKey('NSSize'))) {
      o.setObjectForKey($.NSNumber.numberWithDouble(size), 'NSSize');
    }
  }
  if (!renamed) throw new Error('font name not found in archive');
  return $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError(pl, 200 /* binary */, 0, err);
}

function run(argv) {
  const fontName = argv[0] || 'HackNFM-Regular';
  const domain = argv[1] || 'com.apple.Terminal';
  const d = $.NSUserDefaults.alloc.initWithSuiteName(domain);

  const wsRaw = d.dictionaryForKey('Window Settings');
  if (nil(wsRaw)) return 'skip: Terminal.app has no saved profiles yet (open Terminal once, then re-run)';
  const ws = wsRaw.mutableCopy;

  const names = [];
  for (const key of ['Default Window Settings', 'Startup Window Settings']) {
    const n = ObjC.unwrap(d.stringForKey(key));
    if (n && !names.includes(n)) names.push(n);
  }
  if (!names.length) names.push('Basic');

  const report = [];
  for (const name of names) {
    const pRaw = ws.objectForKey(name);
    if (nil(pRaw)) { report.push(`${name}: not customised yet, skipped`); continue; }
    const p = pRaw.mutableCopy;

    // Home (F729) / End (F72B) → send to the shell
    const kmRaw = p.objectForKey('keyMapBoundKeys');
    const km = nil(kmRaw) ? $.NSMutableDictionary.dictionary : kmRaw.mutableCopy;
    km.setObjectForKey($('\u001b[H'), 'F729');
    km.setObjectForKey($('\u001b[F'), 'F72B');
    p.setObjectForKey(km, 'keyMapBoundKeys');

    if (fontName === '-') { ws.setObjectForKey(p, name); report.push(`${name}: Home/End`); continue; }

    // Font → Nerd Font, same size
    const fd = p.objectForKey('Font');
    const newFont = nil(fd)
      ? retargetFont($.NSData.alloc.initWithBase64EncodedStringOptions(FONT_TEMPLATE, 0), fontName, DEFAULT_SIZE_WITHOUT_FONT)
      : retargetFont(fd, fontName, 0);
    p.setObjectForKey(newFont, 'Font');

    ws.setObjectForKey(p, name);
    report.push(`${name}: Home/End + ${fontName}`);
  }

  d.setObjectForKey(ws, 'Window Settings');
  d.synchronize;
  return report.join('\n');
}
