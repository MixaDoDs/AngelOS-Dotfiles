# Security Policy

> This document is published in two parts. **Part A is the authoritative English
> version.** Part B is a Turkish translation provided for convenience. If the two
> ever diverge, the English version governs.
>
> This file is a drop-in template: it refers to "this project" / "this
> repository" throughout, so it is legally valid in any repository without
> editing. You do not need to write a separate policy per project.

Maintainer: **Mustafa Ihsan Albayrak (@miabeyefendi)** - https://github.com/Miabeyefendi

> **Important notice.** This project is not a commercially supported product. It
> has no 24/7 on-call team, no Service-Level Agreement (SLA), and no paid support.
> It is an independent, open-source, hobby-grade project. Please set your
> expectations accordingly.

---

## PART A - ENGLISH

### 1. Scope and legal grounding

Many of these projects are automation tools, scrapers, browser extensions, or
utilities that interact with third-party platforms (for example Instagram,
Letterboxd, Steam, Discord, GitHub, and similar). Because of this:

- **You are responsible for your own use.** Any data loss, hardware fault,
  account restriction, IP ban, or legal consequence that results from running
  this software is your responsibility alone, as the operator and end user.
- **The code is a neutral tool.** Publishing source code is an expression of
  programming technique for educational and personal use. It is not an
  instruction to break any law or any platform's Terms of Service.
- **No affiliation.** The third-party platforms named or targeted by any project
  are not affiliated with, endorsed by, or partnered with the maintainer. All
  trademarks belong to their respective owners and are referenced only for
  identification and interoperability (nominative fair use).
- **Warranty and liability** are governed by the LICENSE file (AGPL-3.0) and the
  supplemental disclaimer in the NOTICE file. The software is provided "as is", with no warranty,
  and the maintainer's liability is excluded to the maximum extent permitted by
  applicable law.

This SECURITY.md does not create any new warranty, support obligation, or
liability beyond what the LICENSE and NOTICE files already state.

### 2. Supported versions

This is a hobby project, so there is no backporting. Security fixes are applied
only to the latest code on the default branch.

| Version / Branch            | Status            | Notes                                                        |
| :-------------------------- | :---------------- | :----------------------------------------------------------- |
| `main` (latest release)     | Supported         | Critical issues are patched on the active branch only.       |
| `beta` / `dev`              | Experimental      | Under active development; no security guarantee.             |
| Older tags / past releases  | Not supported     | Vulnerabilities in old versions are not fixed - please update.|

### 3. Threat model: what counts as a vulnerability

To avoid wasting your time and mine, please understand what is and is not a
security issue.

**In scope (please report):**
- The software leaking your API keys, passwords, tokens, or session cookies to a
  third party.
- A genuine remote code execution (RCE), injection, or cross-site scripting (XSS)
  vulnerability, or any backdoor.
- A vulnerability that grants access to the maintainer's own servers or accounts.
- Use of a known-vulnerable dependency that is actually exploitable in this code.

**Out of scope (please do NOT report as a security issue):**
- "I ran the bot non-stop for 24 hours and my account got banned." That is an
  operational/usage outcome, not a vulnerability.
- The tool breaking because a target website changed its interface or API.
- The source code being readable or reverse-engineerable. It is open source by
  design; readability is expected.
- Theoretical findings from an automated scanner with no demonstrated, practical
  impact in this codebase.

### 4. How to report a vulnerability

For anything in scope, there is exactly one correct path.

**Do NOT open a public Issue, Discussion, or Pull Request for a security report.**
Public disclosure puts every user at risk before a fix exists.

Instead:

1. **Contact me privately and directly** through the contact details on my GitHub
   profile, or by direct message to **@miabeyefendi** on the social/chat accounts
   linked there (for example Discord or X/Twitter).
2. Start your message with the prefix **`[SECURITY VULNERABILITY]`**, optionally
   followed by the repository name, so it is easy to separate from spam.
3. Include the following so the issue can be reproduced:
   - the affected file and line(s);
   - clear, step-by-step reproduction instructions (a proof of concept);
   - the realistic impact (for example: "this lets an attacker steal user tokens");
   - your environment (operating system, runtime version, browser, etc.).

### 5. Coordinated disclosure and credit

- **No bug bounty.** This is not a company, so please do not expect a monetary
  reward.
- **Credit where due.** Once a report is verified and a fix is released, you will
  be credited by name in the release notes and the README, unless you prefer to
  remain anonymous - which I will respect.
- **Please be patient.** Keeping the issue private until a fix ships is the basis
  of good-faith coordinated disclosure. Give me reasonable time to respond and
  patch before any public mention.

### 6. Good-faith research safe harbor

If you act in good faith to find and report a vulnerability under this policy -
without violating the privacy of users, without destroying data, without
degrading the service for others, and without accessing more data than is
necessary to demonstrate the issue - I will not pursue or support any action
against you for that research, to the extent it is within my control. This safe
harbor does not authorize testing against third-party platforms or any system you
do not own or have permission to test.

---

## PART B - TÜRKÇE

> Bu belge iki bölüm halinde yayınlanmıştır. **Yetkili (geçerli) metin Bölüm A,
> İngilizce sürümüdür.** Bölüm B, kolaylık amacıyla sağlanan Türkçe çeviridir.
> İkisi arasında bir farklılık olursa İngilizce sürüm geçerlidir.
>
> Bu dosya yerine doğrudan kullanılabilen bir şablondur: baştan sona "bu proje" /
> "bu depo" ifadelerine atıf yapar, bu yüzden hiçbir düzenleme yapmadan her
> depoda hukuken geçerlidir. Her proje için ayrı politika yazmanız gerekmez.

Yürütücü (maintainer): **Mustafa İhsan Albayrak (@miabeyefendi)** - https://github.com/Miabeyefendi

> **Önemli bildirim.** Bu proje, ticari olarak desteklenen bir ürün değildir.
> 7/24 nöbetçi bir ekibi, Hizmet Seviyesi Anlaşması (SLA) veya ücretli desteği
> yoktur. Bağımsız, açık kaynaklı, hobi seviyesinde bir projedir. Beklentilerinizi
> buna göre ayarlayın.

### 1. Kapsam ve yasal zemin

Bu projelerin çoğu; üçüncü taraf platformlarla (örneğin Instagram, Letterboxd,
Steam, Discord, GitHub ve benzerleri) etkileşen otomasyon araçları, scraper'lar,
tarayıcı eklentileri veya araçlardır. Bu nedenle:

- **Kendi kullanımınızdan siz sorumlusunuz.** Bu yazılımı çalıştırmaktan doğan
  her türlü veri kaybı, donanım arızası, hesap kısıtlaması, IP yasağı veya yasal
  sonuç; işletici ve son kullanıcı olarak yalnızca sizin sorumluluğunuzdadır.
- **Kod nötr bir araçtır.** Kaynak kod yayınlamak; eğitim ve kişisel kullanım
  için bir programlama tekniği ifadesidir. Herhangi bir yasayı veya platformun
  Kullanım Koşullarını (TOS) ihlal etme talimatı değildir.
- **Bağlantı yoktur.** Herhangi bir projenin adını andığı veya hedef aldığı
  üçüncü taraf platformlar; yürütücü ile bağlı, onaylanmış veya ortak değildir.
  Tüm ticari markalar ilgili sahiplerine aittir ve yalnızca tanımlama ile
  birlikte çalışabilirlik amacıyla anılmıştır (nominatif/dürüst kullanım).
- **Garanti ve sorumluluk**, LICENSE dosyası (AGPL-3.0) ve NOTICE dosyasındaki ek
  feragatname ile düzenlenir. Yazılım "olduğu gibi", garanti olmaksızın sunulur ve yürütücünün
  sorumluluğu, uygulanabilir yasanın izin verdiği azami ölçüde hariç tutulur.

Bu SECURITY.md; LICENSE ve NOTICE dosyalarının hâlihazırda belirttiğinin ötesinde
hiçbir yeni
garanti, destek yükümlülüğü veya sorumluluk yaratmaz.

### 2. Desteklenen sürümler

Bu bir hobi projesi olduğundan geriye dönük yama (backport) yapılmaz. Güvenlik
düzeltmeleri yalnızca varsayılan daldaki en güncel koda uygulanır.

| Sürüm / Dal                 | Durum             | Açıklama                                                       |
| :-------------------------- | :---------------- | :------------------------------------------------------------ |
| `main` (en güncel sürüm)    | Destekleniyor     | Kritik sorunlar yalnızca aktif dalda yamalanır.               |
| `beta` / `dev`              | Deneysel          | Aktif geliştirme aşamasında; güvenlik garantisi yoktur.       |
| Eski tag'ler / geçmiş sürümler | Desteklenmiyor | Eski sürümlerdeki açıklar düzeltilmez - lütfen güncelleyin.   |

### 3. Tehdit modeli: neye güvenlik açığı denir

Hem sizin hem benim zamanımızı boşa harcamamak adına, neyin güvenlik sorunu olup
olmadığını netleştirelim.

**Kapsam içinde (lütfen bildirin):**
- Yazılımın; API anahtarlarınızı, şifrelerinizi, token'larınızı veya oturum
  çerezlerinizi bir üçüncü tarafa sızdırması.
- Gerçek bir uzaktan kod yürütme (RCE), enjeksiyon veya siteler arası
  betik çalıştırma (XSS) zafiyeti ya da herhangi bir arka kapı.
- Yürütücünün kendi sunucularına veya hesaplarına erişim sağlayan bir zafiyet.
- Bu kodda gerçekten sömürülebilir, bilinen-zafiyetli bir bağımlılığın kullanımı.

**Kapsam dışı (lütfen güvenlik sorunu olarak BİLDİRMEYİN):**
- "Botu 24 saat aralıksız çalıştırdım, hesabım ban yedi." Bu bir kullanım sonucu,
  zafiyet değil.
- Hedef sitenin arayüzünü veya API'sini değiştirmesi yüzünden aracın bozulması.
- Kaynak kodun okunabilir veya tersine mühendislik yapılabilir olması. Tasarım
  gereği açık kaynaktır; okunabilir olması normaldir.
- Otomatik bir tarayıcıdan çıkan, bu kod tabanında gösterilmiş pratik etkisi
  olmayan teorik bulgular.

### 4. Güvenlik açığı nasıl bildirilir

Kapsam içindeki her şey için tek bir doğru yol vardır.

**Güvenlik bildirimi için halka açık Issue, Discussion veya Pull Request
AÇMAYIN.** Halka ifşa, daha bir yama hazır olmadan tüm kullanıcıları riske atar.

Bunun yerine:

1. **Benimle özel ve doğrudan iletişime geçin:** GitHub profilimdeki iletişim
   bilgileri üzerinden veya orada bağlı sosyal/sohbet hesaplarından
   **@miabeyefendi** adresine Özel Mesaj (DM) ile (örneğin Discord veya
   X/Twitter).
2. Mesajınızı, spam'den kolayca ayrılabilmesi için **`[SECURITY VULNERABILITY]`**
   önekiyle başlatın; isteğe bağlı olarak depo adını ekleyebilirsiniz.
3. Sorunun tekrar üretilebilmesi için şunları ekleyin:
   - etkilenen dosya ve satır(lar);
   - net, adım adım tekrar üretme talimatları (kavram kanıtı / proof of concept);
   - gerçekçi etki (örneğin: "bu açıkla saldırgan kullanıcı token'larını çalabilir");
   - çalışma ortamınız (işletim sistemi, çalışma zamanı sürümü, tarayıcı vb.).

### 5. Koordineli ifşa ve kredi

- **Bug bounty yoktur.** Bir şirket olmadığım için parasal ödül beklemeyin.
- **Hak sahibine kredi.** Bir bildirim doğrulanıp düzeltme yayınlandığında;
  anonim kalmak istemediğiniz sürece sürüm notlarında ve README'de adınızla
  anılırsınız. Anonim kalmak isterseniz buna saygı duyarım.
- **Lütfen sabredin.** Düzeltme çıkana kadar sorunu gizli tutmak, iyi niyetli
  koordineli ifşanın temelidir. Herhangi bir halka açık paylaşımdan önce yanıt
  vermem ve yama hazırlamam için makul süre tanıyın.

### 6. İyi niyetli araştırma güvenli limanı (safe harbor)

Bu politika kapsamında iyi niyetle - kullanıcıların gizliliğini ihlal etmeden,
veri imha etmeden, başkaları için hizmeti bozmadan ve sorunu göstermek için
gerekenden fazla veriye erişmeden - bir zafiyet bulup bildirirseniz; kontrolüm
dahilinde olduğu ölçüde, bu araştırma nedeniyle size karşı herhangi bir işlem
başlatmam veya desteklemem. Bu güvenli liman; üçüncü taraf platformlara ya da
sahibi olmadığınız veya test izniniz bulunmayan herhangi bir sisteme karşı
test yapmaya yetki vermez.
