"""Run the actual assistant registration API in Qt without desktop services."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AssistantHookTests(unittest.TestCase):
 def test_provider_lifecycle(self):
  source=(ROOT/'services/Angel.qml').read_text()
  api=source[source.index('    property var assistant:'):source.index('    property double hiddenUntil:')]
  with tempfile.TemporaryDirectory() as tmp:
   path=Path(tmp)
   (path/'AngelHook.qml').write_text('import QtQuick\nQtObject {\n property bool menuOpen: true\n property string menuMode: "assistant"\n function hush() { menuOpen=false; menuMode="main" }\n'+api+'\n}')
   (path/'tst_assistant.qml').write_text('''import QtQuick
import QtTest
TestCase {
 name:"AssistantHook"
 AngelHook { id:hook }
 QtObject { id:first; property string helperUrl:"file:///first.qml" }
 QtObject { id:second; property string helperUrl:"file:///second.qml" }
 function test_lifecycle() {
   verify(!hook.registerAssistant("",first)); verify(hook.registerAssistant("first",first)); compare(hook.assistantUrl,"file:///first.qml");
   verify(!hook.registerAssistant("second",second)); hook.unregisterAssistant("first",second); compare(hook.assistant,first);
   hook.unregisterAssistant("other",first); compare(hook.assistant,first);
   hook.unregisterAssistant("first",first); compare(hook.assistant,null); compare(hook.assistantUrl,""); verify(!hook.menuOpen);
   verify(hook.registerAssistant("second",second)); compare(hook.assistantUrl,"file:///second.qml");
 }
}''')
   r=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',tmp],capture_output=True,text=True,env={**os.environ,'QT_QPA_PLATFORM':'offscreen','QT_QUICK_BACKEND':'software'},timeout=30)
   self.assertEqual(r.returncode,0,r.stdout+r.stderr)
if __name__=='__main__':unittest.main()
