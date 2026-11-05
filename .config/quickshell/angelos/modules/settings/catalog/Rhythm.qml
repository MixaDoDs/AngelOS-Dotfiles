pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// Music and rhythm (tree.json "rhythm"): everything that moves with the music. The page is put
// together from groups that live by their features — the wallpaper's (Wallpaper "scene-rhythm"),
// the Halo's ("bass"), the windows' ("kick"), the angel's (Y2k "nod"), the lyrics' ("beat"); this
// file holds what belongs to none of them: how the shell hears the music (services/Bass).
CatPage {
    id: page
    heading: I18n.t("Музыка и ритм", "Music and rhythm")
    subtitle: I18n.t("Всё, что двигается под музыку: обои, Нимб, окна, ангел, текст песни.", "Everything that moves with the music: the wallpaper, the Halo, the windows, the angel, the lyrics.")
    CatGroup {
        name: "hearing"
        title: I18n.t("Слух", "Hearing")
        icon: "volume"
        CatNote {
            text: !Lyrics.playing ? I18n.t("Сейчас музыка не играет — всё на этой странице ждёт песню.", "No music plays now — everything on this page waits for a song.") : Power.eco ? I18n.t("Включён режим экономии: под музыку ничего не двигается.", "The eco mode is on: nothing moves with the music.") : !Bass.wanted ? I18n.t("Музыка играет, но всё, что слушает бас, выключено или не на экране.", "Music plays, but all that listens to the bass is off or not on screen.") : (Bass.earOn ? I18n.t("Слушает angel-ear", "angel-ear is listening") : I18n.t("Слушает cava", "cava is listening")) + (Bass.bpm > 0 ? " · " + Bass.bpm + I18n.t(" ударов в минуту", " beats a minute") : "")
        }
        CatToggle {
            label: I18n.t("Свой слух angel-ear", "angelOS's own hearing, angel-ear")
            hint: Bass.earGone ? I18n.t("angel-ear не запустился, слушает cava. Выключи и включи, чтобы попробовать снова", "angel-ear didn't start, cava is listening. Turn off and on to try again") : I18n.t("своя программа angelOS: ловит бочку, малый барабан и тарелки; выключено — их ловит cava", "angelOS's own program: it catches the kick, the snare and the cymbals; off — cava catches them")
            checked: Config.system.angelEar
            onToggled: c => Config.system.angelEar = c
        }
    }
}
