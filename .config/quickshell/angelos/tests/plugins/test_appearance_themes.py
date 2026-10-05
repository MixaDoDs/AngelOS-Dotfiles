from pathlib import Path
import subprocess,tempfile,os
base=Path(__file__).resolve().parents[2]
s=(base/'services/Plugins.qml').read_text()
section=s[s.index('    // Optional manifest contributions'):s.index('    // context object handed')]
with tempfile.TemporaryDirectory() as tmp:
    root=Path(tmp)
    def write(rel,text):
        p=root/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
    write('imports/qs/config/qmldir','module qs.config\nsingleton Config 1.0 Config.qml\n')
    write('imports/qs/config/Config.qml','pragma Singleton\nimport QtQuick\nQtObject { property QtObject appearance: QtObject { property string flavor: "overdose" } }')
    write('imports/qs/services/qmldir','module qs.services\nsingleton Cursors 1.0 Cursors.qml\nsingleton Shell 1.0 Shell.qml\n')
    write('imports/qs/services/Cursors.qml','pragma Singleton\nimport QtQuick\nQtObject { property bool busy: false; property var other: ["Bibata-Modern-Ice","Bibata-Wallpaper-123456"]; property int size: 24; property string theme: ""; function apply(n,s) { theme=n; size=s } }')
    write('imports/qs/services/Shell.qml','pragma Singleton\nimport QtQuick\nQtObject { property string page: ""; function openSettings(p) { page=p } }')
    write('ThemeContributions.qml','''import QtQuick
import qs.config
import qs.services
Item {
 id: root
 property var records: []
 property var saved: ({})
 readonly property var enabledPlugins: records.filter(p=>p.enabled)
 function byId(id) { return records.find(p=>p.id===id) }
 function isEnabled(p) { return p.enabled }
 function context(p) { return {get:(k,d)=>saved[p.id] && saved[p.id][k] !== undefined ? saved[p.id][k] : d, set:(k,v)=>{ const n=Object.assign({},saved); n[p.id]=Object.assign({},n[p.id]||{}); n[p.id][k]=v; saved=n; }} }
'''+section+'\n}')
    write('tst_themes.qml','''import QtQuick
import QtTest
import qs.config
import qs.services
import "."
TestCase {
 name: "PluginAppearanceThemes"
 ThemeContributions { id: t }
 function init() {
   Cursors.busy=false; Cursors.theme=""; Shell.page=""; t.saved={}; t.appearanceSelection="";
   t.records=[{id:"cursor",enabled:true,appearanceThemes:[{id:"ice",kind:"cursor",theme:"Bibata-Modern-Ice"},{id:"wallpaper",kind:"cursor",themeSetting:"wallpaperTheme"}]}, {id:"emoji",enabled:true,appearanceThemes:[{id:"dark",kind:"plugin-settings",settings:{theme:"dark",bad:{nested:1}}},{id:"custom",kind:"settings"}]}];
 }
 function test_cursor() { verify(t.applyAppearanceTheme("plugin-theme:cursor:ice")); compare(Cursors.theme,"Bibata-Modern-Ice"); compare(t.saved.cursor.theme,"Bibata-Modern-Ice"); }
 function test_wallpaper() { t.saved={cursor:{wallpaperTheme:"Bibata-Wallpaper-123456"}}; verify(t.applyAppearanceTheme("plugin-theme:cursor:wallpaper")); compare(Cursors.theme,"Bibata-Wallpaper-123456"); compare(t.saved.cursor.theme,"wallpaper"); }
 function test_not_ready() { verify(!t.applyAppearanceTheme("plugin-theme:cursor:wallpaper")); Cursors.busy=true; verify(!t.applyAppearanceTheme("plugin-theme:cursor:ice")); compare(Cursors.theme,""); }
 function test_scoped_settings() { verify(t.applyAppearanceTheme("plugin-theme:emoji:dark")); compare(t.saved.emoji.theme,"dark"); compare(t.saved.emoji.bad,undefined); compare(t.saved.cursor,undefined); }
 function test_customize() { verify(t.applyAppearanceTheme("plugin-theme:emoji:custom")); compare(Shell.page,"plugin:emoji"); }
 function test_disabled_and_invalid() { t.records=[{id:"off",enabled:false,appearanceThemes:[{id:"x",kind:"settings"}]},{id:"bad",enabled:true,appearanceThemes:[{id:"../escape",kind:"settings"},{id:"x",kind:"exec"},{id:"y",kind:"plugin-settings",settings:[]},{id:"ok",kind:"settings"},{id:"ok",kind:"settings"}]}]; compare(t.appearanceThemes.length,1); verify(!t.applyAppearanceTheme("plugin-theme:off:x")); }
 function test_palette_clears_selection() { t.applyAppearanceTheme("plugin-theme:emoji:dark"); Config.appearance.flavor="test"; compare(t.appearanceSelection,""); }
}
''')
    r=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(root),'-import',str(root/'imports')],env={**os.environ,'QT_QPA_PLATFORM':'offscreen','QT_QUICK_BACKEND':'software'},capture_output=True,text=True)
    print(r.stdout+r.stderr);raise SystemExit(r.returncode)
