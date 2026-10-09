var _d=[];function L(t){_d.push(t)}
L("=== PLAYBAR DIAGNOSTIC ===");
var rs=getComputedStyle(document.documentElement);
L("--spice-playbar: "+rs.getPropertyValue("--spice-playbar"));
L("--spice-player: "+rs.getPropertyValue("--spice-player"));
L("--spice-main: "+rs.getPropertyValue("--spice-main"));
L("--spice-sidebar: "+rs.getPropertyValue("--spice-sidebar"));
L("--spice-text: "+rs.getPropertyValue("--spice-text"));
L("");
var bar=document.querySelector(".Root__now-playing-bar")||document.querySelector("footer[data-testid='now-playing-bar']");
if(bar){
L("BAR FOUND: <"+bar.tagName+"> class="+bar.className.substring(0,100));
var bs=getComputedStyle(bar);
L("bar background-color: "+bs.backgroundColor);
L("bar --background-base: "+bs.getPropertyValue("--background-base"));
L("bar --background-elevated-base: "+bs.getPropertyValue("--background-elevated-base"));
L("bar --background-highlight: "+bs.getPropertyValue("--background-highlight"));
L("");
L("=== ALL --spice-* on :root ===");
var all=document.documentElement.style.cssText;
if(all){all.split(";").forEach(function(p){p=p.trim();if(p.indexOf("--spice")>-1)L(p)})}else{L("(no inline styles on :root)")}
L("");
L("=== PLAYER BAR CHILDREN ===");
for(var i=0;i<bar.children.length;i++){var c=bar.children[i];L("child["+i+"]: <"+c.tagName+"> class="+c.className.substring(0,80)+" bg="+getComputedStyle(c).backgroundColor)}
}else{L("BAR NOT FOUND")}
L("");
L("=== CSS RULES WITH playbar ===");
try{var sheets=document.styleSheets;for(var s=0;s<sheets.length;s++){try{var rules=sheets[s].cssRules;for(var r=0;r<rules.length;r++){if(rules[r].cssText&&rules[r].cssText.indexOf("spice-playbar")>-1){L("RULE: "+rules[r].cssText.substring(0,200))}}}catch(e){}}}catch(e){L("cant read sheets")}
var out=_d.join("\n");
copy(out);
console.log(out);
console.log("\n✅ COPIED TO CLIPBOARD");
