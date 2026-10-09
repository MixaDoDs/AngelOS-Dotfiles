<div align="center">

<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/assets/logo-dark.svg" width="110" alt="Vantagraph Custom">

# Vantagraph Custom

**La edición lite de Vantagraph. Sin paletas predefinidas: cada color que pinta el tema lo eliges tú, desde un editor que vive dentro de la aplicación.**

[![Licencia: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-A78BFA?style=for-the-badge&logo=gnu&logoColor=white)](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/LICENSE)
[![Versión](https://img.shields.io/github/v/release/Miabeyefendi/Vantagraph-Custom?style=for-the-badge&color=F59E0B&label=version)](https://github.com/Miabeyefendi/Vantagraph-Custom/releases/latest)
[![Descargas](https://img.shields.io/github/downloads/Miabeyefendi/Vantagraph-Custom/total?style=for-the-badge&color=22C55E&label=downloads)](https://github.com/Miabeyefendi/Vantagraph-Custom/releases)
[![Spicetify](https://img.shields.io/badge/Spicetify_2.43%2B-1E293B?style=for-the-badge&logo=spotify&logoColor=white)](https://spicetify.app/)

[English](https://github.com/Miabeyefendi/Vantagraph-Custom#readme) · [Türkçe](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_TR.md) · [Español](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_ES.md) · [简体中文](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_ZH.md) · [Русский](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_RU.md)


<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/palettes-grid.png" width="94%" alt="La misma pantalla de Spotify en seis paletas hechas con el editor: VantagraphBlack, Plum, Ocean, Forest, Ember y Paper">

</div>

---

## ✨ Qué te llevas

**Un editor de color, no una lista de paletas.** Treinta y seis colores, agrupados según dónde pintan: superficies, texto e iconos, botones, barras de progreso, líneas y sombras, los tintes de cristal que se usan sobre una imagen de fondo y los pocos colores que Spotify dibuja por su cuenta. Cada uno acepta HEX, RGB, RGBA o HSL, tiene su propia opacidad y cambia Spotify mientras arrastras.

**Un selector que hace todo el trabajo.** Un campo de saturación, franjas de tono y de opacidad, un cuentagotas que toma el color de cualquier cosa en pantalla, campos R G B A, valores escritos en cualquier formato, tu paleta y tus últimos colores como muestras a un clic, deshacer y rehacer, y un buscador.

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/editor-picker.png" width="82%" alt="El editor de color abierto dentro de Spotify: campo de color, franjas de tono y opacidad, entrada HEX, RGB y HSL, y muestras de la paleta">
</div>

**Colores que siguen a otros hasta que digas lo contrario.** El texto del menú sigue a Text, los iconos siguen a Subtext y el símbolo de reproducción sigue a Panel. Cambia el color de origen y se van con él. Dale a uno un valor propio y deja de seguirlo; un clic lo vuelve a enlazar.

**Mira dónde pinta cada color.** Pulsa el icono de diana junto a cualquier color y parpadea dentro de Spotify, así "Stroke" o "Glass Edge" nunca son una adivinanza.

**Paletas que se comparten.** Copia la paleta entera como texto, pega la de otra persona o pega directamente líneas de `color.ini` de otro tema.

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/editor-share.png" width="82%" alt="El panel Share con una paleta de ejemplo lista para copiar o probar con un clic">
</div>

**El resto de Vantagraph, sin el juego de iconos.** Pestañas de tipografía, disposición, fondo y snippets, karaoke de letras en imagen sobre imagen, un reproductor de barra de tareas, volumen con la rueda del ratón y bucles por pista. Esta edición no toca los iconos de Spotify, así que una actualización que los redibuje no puede romperla.

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/background-glass.png" width="82%" alt="La portada del álbum como imagen de fondo detrás de paneles de cristal teñidos con los colores de cristal del editor">
</div>

---

## 📦 Instalación

Necesitas [Spotify](https://www.spotify.com/download/) `1.2.86+` y [Spicetify](https://spicetify.app/docs/getting-started) `2.43+`.

La vía más corta es Spicetify Marketplace: busca **Vantagraph Custom** y pulsa Install. Para instalarlo a mano:

Copia este repositorio en `…/spicetify/Themes/` como una carpeta llamada `vantagraph-custom`, y cada `.js` de su carpeta `Extensions/` en `…/spicetify/Extensions/`. Después:

```bash
spicetify config inject_css 1 replace_colors 1 overwrite_assets 1 inject_theme_js 1
spicetify config current_theme vantagraph-custom
spicetify config extensions vantagraph-custom-settings.js
spicetify apply
```

Spotify se reinicia con la paleta VantagraphBlack y un botón nuevo en la barra superior. Ábrelo, quédate en **Colors** y empieza a cambiar cosas. Las extensiones opcionales y la vuelta al Spotify de siempre están en la [guía de instalación](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/INSTALL.md).

> ¿Ya usas [Vantagraph](https://github.com/Miabeyefendi/Vantagraph)? Usa uno u otro. Con los dos juegos de extensiones activos tendrás dos botones de ajustes y dos ruedas de volumen.

---

## 📖 Documentación

| | |
|---|---|
| [**Instalación**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/INSTALL.md) | Todas las rutas de instalación, qué hace cada extensión y cómo desinstalar sin dejar restos |
| [**El editor de color**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/COLORS.md) | Los treinta y seis colores, qué pinta cada uno y cada herramienta del selector |
| [**Ajustes**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/SETTINGS.md) | Las otras cuatro pestañas, cada control y cada snippet |
| [**Extensiones**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/EXTENSIONS.md) | Las extensiones en detalle, y los créditos sobre los que están construidas |
| [**Guía técnica**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/guides/TUTORIAL.md) | Cómo llega un color del editor a la pantalla |
| [**Cambios**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/CHANGELOG.md) | Qué cambió en cada versión |

> ¿Estás leyendo esto dentro de Spotify? Los enlaces de arriba se abren en tu navegador. Todo lo que necesitas para instalar el tema ya está en esta página.

---

## 📜 Licencia y créditos

Vantagraph Custom es **AGPL-3.0**, con los términos de atribución en [NOTICE](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/NOTICE). Úsalo, cámbialo y distribúyelo, mientras el código siga abierto y la atribución intacta. Está construido sobre [Vantagraph](https://github.com/Miabeyefendi/Vantagraph), del mismo autor.

Tres de las extensiones son reescrituras sobre trabajo anterior de [Aspecky](https://github.com/Aspecky), khanhas y los mantenedores de [Spicetify](https://github.com/spicetify), y [FO-SS](https://github.com/FO-SS). Qué aportó cada uno, y qué se añadió encima, está detallado en la [guía de extensiones](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/EXTENSIONS.md#credits).

Spotify no está afiliado a este proyecto ni lo respalda. El tema modifica el cliente de escritorio localmente; lo ejecutas por tu cuenta y riesgo.

<div align="center">
<br/>
<sub>Creado por <b><a href="https://github.com/Miabeyefendi">Miabeyefendi</a></b></sub>
</div>
