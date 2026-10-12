// the launcher's currency phrases (services/CalcCore.js money): the sum, the pair, the home currency
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const src = readFileSync(new URL("../../services/CalcCore.js", import.meta.url), "utf8").replace(/^\.pragma library/m, "");
const C = new Function(src + "\nreturn { money, convert, math };")();
const rates = { USD: 1, EUR: 0.9, RUB: 95, GBP: 0.8, THB: 36 };
const m = (t, home = "RUB") => C.money(t, rates, home);
const is = (t, amount, from, to, home) => assert.deepEqual(m(t, home), { amount, from, to }, t);

is("100 usd в rub", 100, "USD", "RUB");
is("50€ to $", 50, "EUR", "USD");
is("1000 рублей в долларах", 1000, "RUB", "USD");
// a lone sum goes home; home itself named → dollars (dollars at home → euros)
is("100$", 100, "USD", "RUB");
is("$ 20", 20, "USD", "RUB");
is("5000 ₽", 5000, "RUB", "USD");
is("10 usd", 10, "USD", "EUR", "USD");
// multipliers and the question around it
is("10к рублей в долларах", 10000, "RUB", "USD");
is("2,5 тыс евро", 2500, "EUR", "RUB");
is("1.2m usd to eur", 1200000, "USD", "EUR");
is("3 млн рублей", 3000000, "RUB", "USD");
is("сколько 100 долларов в рублях?", 100, "USD", "RUB");
is("how much is 20 pounds in usd", 20, "GBP", "USD");
// the rate of one
is("курс доллара", 1, "USD", "RUB");
is("курс евро к рублю", 1, "EUR", "RUB");
is("курс thb", 1, "THB", "RUB");
// not money: units, maths and words stay theirs
for (const t of ["10 km in mi", "100 m to ft", "3 min", "2 + 2", "10 kg", "100", "курс", "100 котиков", "5 k"])
    assert.equal(m(t), null, t);
assert.ok(C.convert("100 m to ft"), "units still convert");
console.log("money ok");
