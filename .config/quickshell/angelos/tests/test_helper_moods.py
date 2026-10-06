"""Exercise the actual helper gesture bindings with motion controls in Qt."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
class HelperMoodTests(unittest.TestCase):
 def test_reactions_respect_motion_and_drag(self):
  source=(ROOT/'modules/y2k/AngelHelper.qml').read_text()
  bindings=[]
  for name in ['assistantMood','assistantBusy','expressive','blinking']:
   line=next(line.strip() for line in source.splitlines() if re.search(r'property (string|bool) '+name+':',line))
   bindings.append(line.replace('Angel.','angel.').replace('Motion.','motion.'))
  rotation=next(line.strip().removeprefix('rotation: ') for line in source.splitlines() if line.strip().startswith('rotation: win.expressive'))
  with tempfile.TemporaryDirectory() as tmp:
   file=Path(tmp)/'tst_moods.qml'
   file.write_text('''import QtQuick
import QtTest
TestCase {
 name:"HelperMoods"
 QtObject { id:provider; property string helperMood:"happy"; property bool helperBusy:false }
 QtObject { id:angel; property var assistant:provider; property string transition:"" }
 QtObject { id:motion; property bool calm:false }
 QtObject { id:grab; property bool held:false }
 QtObject {
   id:win; property int tick:1; property bool clockOn:true; property bool awake:true;
'''+ '\n'.join(bindings)+'\nreadonly property real rotation: '+rotation+'''
 }
 function test_reactions() {
   verify(win.blinking); verify(win.rotation!==0);
   motion.calm=true; verify(!win.blinking); compare(win.rotation,0); motion.calm=false;
   grab.held=true; compare(win.rotation,0); grab.held=false;
   provider.helperMood="thinking"; provider.helperBusy=true; verify(win.rotation!==0); verify(!win.blinking);
   angel.transition="ascend"; compare(win.rotation,0); angel.transition="";
   angel.assistant=null; compare(win.assistantMood,""); compare(win.rotation,0);
 }
}''')
   r=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',tmp],capture_output=True,text=True,env={**os.environ,'QT_QPA_PLATFORM':'offscreen','QT_QUICK_BACKEND':'software'},timeout=30)
   self.assertEqual(r.returncode,0,r.stdout+r.stderr)
if __name__=='__main__':unittest.main()
