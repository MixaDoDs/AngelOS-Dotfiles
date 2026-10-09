# Contributing Guidelines

> This document is published in two parts. **Part A is the authoritative English
> version.** Part B is a Turkish translation provided for convenience. If the two
> ever diverge, the English version governs.

Maintainer: **Mustafa Ihsan Albayrak (@miabeyefendi)** - https://github.com/Miabeyefendi

Thank you for taking the time to contribute. Reporting a bug, suggesting a
feature, or sending code all genuinely help. Before you start, please read the
short ground rules below - they exist to keep the project tidy and to protect the
work that goes into it.

I am an independent developer, not a corporate engineering team. I value clear,
simple contributions over bureaucracy, long meetings, and heavy process.

---

## PART A - ENGLISH

### 1. License of contributions (read first)

By submitting any contribution (a Pull Request, patch, or other material), you
agree that:

- Your contribution is **your own original work**, or you have the right to
  submit it, and it does not knowingly infringe anyone else's copyright, patent,
  trademark, or other rights.
- Your contribution is licensed under the project's license, the **GNU Affero
  General Public License v3.0 (AGPL-3.0)**, the same terms as the rest of the
  project. See the LICENSE and NOTICE files.
- You retain copyright on your own contribution; you are simply licensing it to
  the project (and its users) under the AGPL-3.0. There is no separate copyright
  assignment.

If you cannot agree to these terms, please do not submit code.

### 2. The red line: zero tolerance for plagiarism

Open source is about sharing knowledge, but exploiting other people's work is not
welcome here. When you contribute:

1. **The code must be yours.** Do not copy code from another developer's
   repository, or from anywhere else, without permission and proper licensing,
   and then submit it as your own. Submit your own work and your own solutions.
2. **Do not strip identity.** Any PR that removes, hides, or alters the author
   attribution, license headers, or legal notices in the project's files will be
   rejected.
3. **Respect the copyleft.** Once merged, your code becomes part of an AGPL-3.0
   project. If your goal is to take this project, add a little code, and turn it
   into a closed-source or hosted commercial product, this is not the place for
   that.

Anyone found committing plagiarism or license abuse will be permanently banned
from the project.

### 3. Reporting a bug

If something is broken, please open an Issue. Reports that just say "it doesn't
work, help" will be closed. Please follow this template:

- **What is the problem?** A short summary of the bug.
- **Steps to reproduce.** What you did, in order (for example: 1. clicked the
  button, 2. entered my password, 3. the screen crashed).
- **Expected result.** What should have happened.
- **Actual result.** What actually happened. Include the error log or a
  screenshot if you can.
- **Environment.** Operating system, runtime/browser version, and project
  version or commit.

For anything that looks like a **security** vulnerability, do NOT open a public
Issue - follow `SECURITY.md` instead.

### 4. Proposing a feature

Got a great idea? Before writing 500 lines of code:

1. Open an Issue and describe the idea in detail.
2. Let's discuss why it's needed and how it fits the project.
3. If it matches the project's direction, I'll say "go ahead and send a PR." This
   spares you the disappointment of writing something that then gets rejected.

### 5. Coding standards

This is not Google or Microsoft. Please do not bring 50-layer, over-engineered,
enterprise-grade architecture.

- **No spaghetti.** Keep code simple and readable. Straightforward logic beats
  clever chains.
- **Comments explain "why".** Comment why the code is written a certain way, not
  what an obvious line does.
- **Match the project style.** Follow the existing `.editorconfig` and
  `.gitattributes` rules for indentation, line endings, and whitespace. If your
  editor supports EditorConfig, this is automatic.

### 6. Pull Request process

When your code is ready:

1. **Fork and branch.** Fork the repository to your own account and create a new
   branch with a clear name, for example `fix/login-error` or `feat/dark-mode`.
2. **Commit messages.** Keep them short, clear, and focused. The
   [Conventional Commits](https://www.conventionalcommits.org/) style is
   preferred.
   - Bad: "changed some stuff in the files"
   - Good: `fix: resolve timeout in the API connection`
3. **Open the PR.** Write a clean description of what you changed and why. Link
   the related Issue if there is one.
4. **Review.** I'll review your code line by line the next time I'm free (and not
   gaming or busy). If something needs changes, I'll leave feedback. Please be
   patient - there is no SLA here.

Thanks again for your effort and respect. Let's build.

---

## PART B - TÜRKÇE

> Bu belge iki bölüm halinde yayınlanmıştır. **Yetkili (geçerli) metin Bölüm A,
> İngilizce sürümüdür.** Bölüm B, kolaylık amacıyla sağlanan Türkçe çeviridir.
> İkisi arasında bir farklılık olursa İngilizce sürüm geçerlidir.

Yürütücü (maintainer): **Mustafa İhsan Albayrak (@miabeyefendi)** - https://github.com/Miabeyefendi

Katkıda bulunmak için zaman ayırdığın için teşekkür ederim. Hata bildirmek,
özellik önermek veya kod göndermek; hepsi gerçekten yardımcı olur. Başlamadan
önce aşağıdaki kısa temel kuralları oku; bunlar projeyi düzenli tutmak ve içine
giren emeği korumak için var.

Ben bağımsız bir geliştiriciyim, kurumsal bir mühendislik ekibi değilim.
Bürokrasiye, uzun toplantılara ve ağır sürece kıyasla; net ve basit katkılara
değer veririm.

### 1. Katkıların lisansı (önce bunu oku)

Herhangi bir katkı (Pull Request, yama veya başka bir materyal) göndererek şunları
kabul edersin:

- Katkın **kendi özgün eserindir** veya onu gönderme hakkına sahipsin ve bilerek
  başkasının telif, patent, ticari marka ya da diğer haklarını ihlal etmiyor.
- Katkın, projenin lisansı olan **GNU Affero General Public License v3.0
  (AGPL-3.0)** altında, projenin geri kalanıyla aynı şartlarla lisanslanır. Bkz.
  LICENSE ve NOTICE dosyaları.
- Kendi katkının telif hakkı sende kalır; onu yalnızca AGPL-3.0 altında projeye
  (ve kullanıcılarına) lisanslamış olursun. Ayrı bir telif devri yoktur.

Bu şartları kabul edemiyorsan lütfen kod gönderme.

### 2. Kırmızı çizgi: intihale sıfır tolerans

Açık kaynak, bilgi paylaşımı üzerine kuruludur; ancak başkalarının emeğini
sömürmek burada hoş karşılanmaz. Katkı yaparken:

1. **Kod sana ait olmalı.** Başka bir geliştiricinin deposundan veya başka bir
   yerden, izinsiz ve uygun lisans olmadan kopyaladığın kodu alıp "ben yazdım"
   diye gönderme. Kendi emeğini ve kendi çözümünü bekliyorum.
2. **Kimlik silme yok.** Projenin dosyalarındaki yazar atfını, lisans başlıklarını
   veya yasal bildirimleri kaldıran, gizleyen ya da değiştiren hiçbir PR kabul
   edilmez.
3. **Copyleft'e saygı.** Birleştirildikten sonra kodun, bir AGPL-3.0 projesinin
   parçası olur. Amacın bu projeyi alıp biraz kod ekleyip kapalı kaynaklı veya
   barındırılan ticari bir ürüne çevirmekse, burası sana göre değil.

İntihal veya lisans suistimali yaptığı tespit edilen herkes projeden kalıcı
olarak banlanır.

### 3. Hata bildirimi

Bir şey bozulduysa lütfen bir Issue aç. Sadece "çalışmıyor, yardım edin" diyen
bildirimler kapatılır. Lütfen şu şablona uy:

- **Sorun nedir?** Hatanın kısa özeti.
- **Tekrarlama adımları.** Ne yaptığını sırasıyla yaz (örneğin: 1. butona bastım,
  2. şifremi girdim, 3. ekran çöktü).
- **Beklenen sonuç.** Ne olması gerekiyordu.
- **Gerçekleşen sonuç.** Gerçekte ne oldu. Mümkünse hata log'unu veya ekran
  görüntüsünü ekle.
- **Çalışma ortamı.** İşletim sistemi, çalışma zamanı/tarayıcı sürümü ve proje
  sürümü veya commit'i.

**Güvenlik** zafiyetine benzeyen her şey için halka açık Issue AÇMA - bunun
yerine `SECURITY.md` dosyasını izle.

### 4. Yeni özellik önerme

Harika bir fikrin mi var? 500 satır kod yazmadan önce:

1. Bir Issue aç ve fikri detaylı anlat.
2. Neden gerektiğini ve projeye nasıl oturduğunu konuşalım.
3. Projenin yönüyle uyuşuyorsa "tamam, PR gönder" derim. Bu, yazıp sonra
   reddedilme hayal kırıklığından seni korur.

### 5. Kod standartları

Burası Google veya Microsoft değil. 50 katmanlı, aşırı mühendislik
(over-engineering) yapılmış, kurumsal mimari bekleme.

- **Spagetti yok.** Kodu basit ve okunabilir tut. Düz mantık, akıllı zincirlerden
  iyidir.
- **Yorumlar "neden"i anlatır.** Bariz bir satırın ne yaptığını değil, kodu neden
  öyle yazdığını açıkla.
- **Proje stiline uy.** Girinti, satır sonu ve boşluk için mevcut `.editorconfig`
  ve `.gitattributes` kurallarını izle. Editörün EditorConfig destekliyorsa bu
  otomatiktir.

### 6. Pull Request süreci

Kodun hazır olduğunda:

1. **Fork ve branch.** Depoyu kendi hesabına forkla ve net isimli yeni bir dal
   aç, örneğin `fix/login-error` veya `feat/dark-mode`.
2. **Commit mesajları.** Kısa, net ve hedefe yönelik olsun.
   [Conventional Commits](https://www.conventionalcommits.org/) stili tercih
   edilir.
   - Kötü: "dosyalarda bişeyleri değiştirdim"
   - İyi: `fix: api bağlantısındaki zaman aşımı sorunu çözüldü`
3. **PR aç.** Ne değiştirdiğini ve neden değiştirdiğini anlatan temiz bir açıklama
   yaz. Varsa ilgili Issue'yu bağla.
4. **İnceleme.** Müsait olduğum (oyun oynamadığım veya meşgul olmadığım) ilk
   fırsatta kodunu satır satır incelerim. Düzeltilmesi gereken yerler varsa geri
   bildirim bırakırım. Lütfen sabret - burada bir SLA yok.

Emeğin ve saygın için tekrar teşekkürler. Başlayalım.
