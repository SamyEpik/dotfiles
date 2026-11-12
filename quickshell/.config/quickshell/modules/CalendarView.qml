import QtQuick
import QtQuick.Controls
import Quickshell
import qs
import qs.components

// Month calendar shown as the clock's tooltip content (Waybar clock "calendar", mode "month",
// weeks on the right, Monday first). A plain Item: the shared TooltipHost draws the box around it.
//
//   CalendarView { monthOffset: 0 }   // months from the current one (-1 = last month)
//
// Layout follows Waybar's <tt> text: every cell is one monospace character column grid
// (days " 9" right-aligned, one space between columns, " W45" on the right), with
// "November 2026" centred over the days (no separate year line: user decision 2026-11-11).
// Always 6 week rows, so the box keeps its size between months (rows after the month's last
// week stay blank). Hardcoded Waybar colours (Theme.cal*).
// Today's highlight and the month follow SystemClock, so they change at midnight.
Item {
    id: root

    property int monthOffset: 0

    // Shown offset; lags behind monthOffset during the month cross-fade (no binding on purpose).
    property int shownOffset: 0
    Component.onCompleted: shownOffset = monthOffset

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    readonly property var now: clock.date
    readonly property int shownMonthIndex: now.getMonth() + shownOffset
    readonly property int shownYear: now.getFullYear() + Math.floor(shownMonthIndex / 12)
    readonly property int shownMonth: ((shownMonthIndex % 12) + 12) % 12   // 0-based like JS Date

    readonly property var enLocale: Qt.locale("en_GB")   // Monday first
    readonly property string monthTitle: enLocale.standaloneMonthName(shownMonth, Locale.LongFormat) + " " + shownYear

    // Days before the 1st in its week (Monday first, 0..6).
    readonly property int lead: (new Date(shownYear, shownMonth, 1).getDay() + 6) % 7
    // Week rows the month needs (4..6). Always 6 rows are shown; the others stay blank.
    readonly property int rows: Math.ceil((lead + new Date(shownYear, shownMonth + 1, 0).getDate()) / 7)
    // MonthGrid always shows some days of the previous month: when the 1st is a Monday its first
    // row is the whole week before (checked in Qt 6.12). Hide that row by shifting the grid up.
    readonly property int shift: lead === 0 ? 1 : 0
    readonly property int shownRows: 6

    // Monospace grid: a day cell is 3 characters (" 9", "10" right-aligned after one space),
    // the week cell is 4 (" W45"). The first column's leading space is cut off (x: -charW).
    FontMetrics {
        id: fm
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: true
    }
    readonly property real charW: fm.advanceWidth("0")
    readonly property real lineH: Math.ceil(fm.height)
    readonly property real cellW: 3 * charW
    readonly property real weekW: 4 * charW
    readonly property real daysW: 7 * cellW - charW      // 20 characters, like `cal`

    implicitWidth: Math.ceil(daysW + weekW)
    implicitHeight: content.y + content.implicitHeight

    // ---- month change: fade out, switch, fade in (150 ms total) -------------------------
    onMonthOffsetChanged: {
        // Hidden windows run no animations: switch directly there.
        if (root.Window.window && root.Window.window.visible)
            monthFade.restart();
        else
            shownOffset = monthOffset;
    }

    SequentialAnimation {
        id: monthFade
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: 75; easing.type: Easing.InCubic }
        ScriptAction { script: root.shownOffset = root.monthOffset }
        NumberAnimation { target: content; property: "opacity"; to: 1; duration: 75; easing.type: Easing.OutCubic }
    }

    Column {
        id: content

        // Month header, centred over the day columns.
        Item {
            width: root.daysW
            height: root.lineH

            BarText {
                anchors.centerIn: parent
                color: Theme.calMonth
                text: root.monthTitle
            }
        }

        DayOfWeekRow {
            x: -root.charW
            width: 7 * root.cellW
            height: root.lineH
            padding: 0
            spacing: 0
            locale: root.enLocale
            background: null

            delegate: BarText {
                required property string shortName
                width: root.cellW
                height: root.lineH
                horizontalAlignment: Text.AlignRight
                color: Theme.calWeekdays
                text: shortName.substring(0, 2)
            }
        }

        Row {
            // Always 6 rows; a leading week of the previous month is clipped away (see `shift`).
            Item {
                width: root.daysW
                height: root.shownRows * root.lineH
                clip: true

                MonthGrid {
                    id: grid
                    x: -root.charW
                    y: -root.shift * root.lineH
                    width: 7 * root.cellW
                    height: 6 * root.lineH
                    padding: 0
                    spacing: 0
                    locale: root.enLocale
                    month: root.shownMonth
                    year: root.shownYear
                    background: null

                    delegate: BarText {
                        id: dayCell
                        required property var model
                        readonly property bool isToday: model.month === grid.month && model.day === root.now.getDate()
                            && model.month === root.now.getMonth() && model.year === root.now.getFullYear()

                        width: root.cellW
                        height: root.lineH
                        horizontalAlignment: Text.AlignRight
                        color: isToday ? Theme.calToday : Theme.calDays
                        font.underline: isToday
                        // Other months' days stay as empty cells (the grid positioner skips
                        // invisible items, so `visible: false` would shift the days).
                        text: model.month === grid.month ? model.day : ""
                    }
                }
            }

            Item {
                width: root.weekW
                height: root.shownRows * root.lineH
                clip: true

                WeekNumberColumn {
                    y: -root.shift * root.lineH
                    width: root.weekW
                    height: 6 * root.lineH
                    padding: 0
                    spacing: 0
                    locale: root.enLocale
                    month: root.shownMonth
                    year: root.shownYear
                    background: null

                    delegate: BarText {
                        required property int weekNumber
                        required property int index
                        // Blank for rows without days of this month.
                        readonly property bool inMonth: index >= root.shift && index - root.shift < root.rows
                        width: root.weekW
                        height: root.lineH
                        horizontalAlignment: Text.AlignRight
                        color: Theme.calWeeks
                        text: inMonth ? "W" + (weekNumber < 10 ? "0" : "") + weekNumber : ""   // %V is 2 digits
                    }
                }
            }
        }
    }
}
