// loads a QML ".pragma library" file of services/ into node: load("CobwebWeb.js")
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
const here = path.dirname(fileURLToPath(import.meta.url));
export function load(name) {
    const src = readFileSync(path.join(here, "../../services", name), "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = [...src.matchAll(/^function (\w+)/gm)].map(m => m[1]).concat([...src.matchAll(/^const (\w+)/gm)].map(m => m[1]));
    return new Function(src + "\nreturn {" + names.join(",") + "};")();
}
export const W = load("CobwebWeb.js");
