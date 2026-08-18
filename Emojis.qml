import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "EmojiData.js" as EmojiData

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property string home: Quickshell.env("HOME")
  property string statePath: home + "/.local/state/omarchy/emojis-state.json"
  property string legacyStatePath: home + "/.config/walker-emoji/state.json"

  property var shell: null
  property var manifest: null

  property bool opened: false
  property int currentTabIdx: 0
  property int selectedIndex: 0
  property bool cursorActive: true

  // Vim Modal Editing: Normal Mode vs Search Mode
  property bool searchMode: false
  property string searchQuery: ""

  property var stateData: ({ "favorites": [], "recent": [] })
  property var currentEmojisList: []

  readonly property string emojiFont: "Noto Color Emoji"

  // Shares the [menu] surface tokens
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.md

  property int cardWidth: Math.min(Style.space(500), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(490), panel.height - Style.gapsOut * 2)

  readonly property int cols: 9
  property int cellWidth: Math.floor((cardWidth - contentMargin * 2) / cols)
  property int cellHeight: cellWidth

  property bool keyboardActive: true

  Timer {
    id: restoreFocusTimer
    interval: 80
    repeat: false
    onTriggered: {
      root.keyboardActive = true
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  function open(payloadJson) {
    root.opened = true
    root.keyboardActive = true
    root.cursorActive = true
    root.searchMode = false
    root.searchQuery = ""
    root.selectedIndex = 0
    root.rebuildGrid()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    root.searchMode = false
    root.searchQuery = ""
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide((root.manifest && root.manifest.id) || "zezenta.vimoji")
    }
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function loadState(raw) {
    try {
      if (raw && raw.trim().length > 0) {
        var parsed = JSON.parse(raw)
        if (parsed && typeof parsed === "object") {
          root.stateData = {
            favorites: Array.isArray(parsed.favorites) ? parsed.favorites : [],
            recent: Array.isArray(parsed.recent) ? parsed.recent : []
          }
          if (root.opened) root.rebuildGrid()
          return
        }
      }
    } catch (e) {
      console.warn("Failed to parse emojis state:", e)
    }
    legacyStateFile.reload()
  }

  function loadLegacyState(raw) {
    try {
      if (raw && raw.trim().length > 0) {
        var parsed = JSON.parse(raw)
        if (parsed && typeof parsed === "object") {
          root.stateData = {
            favorites: Array.isArray(parsed.favorites) ? parsed.favorites : [],
            recent: Array.isArray(parsed.recent) ? parsed.recent : []
          }
          persistState()
          if (root.opened) root.rebuildGrid()
        }
      }
    } catch (e) {
      console.warn("Failed to parse legacy emojis state:", e)
    }
  }

  function persistState() {
    var out = JSON.stringify(root.stateData, null, 2) + "\n"
    stateFile.setText(out)
  }

  function rebuildGrid() {
    var list
    if (root.searchQuery.trim().length > 0) {
      list = EmojiData.searchEmojis(root.searchQuery, 250)
    } else {
      list = EmojiData.getEmojisForTab(root.currentTabIdx, root.stateData)
    }
    root.currentEmojisList = list

    var count = list.length
    if (count === 0) {
      root.selectedIndex = 0
    } else if (root.selectedIndex >= count) {
      root.selectedIndex = count - 1
    } else if (root.selectedIndex < 0) {
      root.selectedIndex = 0
    }

    Qt.callLater(function() {
      if (root.currentEmojisList.length > 0) {
        resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
      }
    })
  }

  function changeTab(delta) {
    if (root.searchQuery.length > 0) {
      root.searchQuery = ""
    }
    var total = EmojiData.TAB_NAMES.length
    root.currentTabIdx = (root.currentTabIdx + delta + total) % total
    root.selectedIndex = 0
    root.rebuildGrid()
  }

  function selectTab(index) {
    if (index >= 0 && index < EmojiData.TAB_NAMES.length) {
      if (root.searchQuery.length > 0) {
        root.searchQuery = ""
      }
      root.currentTabIdx = index
      root.selectedIndex = 0
      root.rebuildGrid()
    }
  }

  function moveSelection(rowDelta, colDelta) {
    var count = root.currentEmojisList.length
    if (count === 0) return
    var rows = Math.ceil(count / root.cols)

    var currRow = Math.floor(root.selectedIndex / root.cols)
    var currCol = root.selectedIndex % root.cols

    var nextRow = currRow + rowDelta
    var nextCol = currCol + colDelta

    // Horizontal wrapping
    if (colDelta !== 0) {
      if (nextCol < 0) {
        if (nextRow > 0) {
          nextRow -= 1
          nextCol = root.cols - 1
        } else {
          nextCol = 0
        }
      } else if (nextCol >= root.cols) {
        if (nextRow < rows - 1) {
          nextRow += 1
          nextCol = 0
        } else {
          nextCol = root.cols - 1
        }
      }
    }

    // Vertical bounds clamping
    if (nextRow < 0) nextRow = 0
    if (nextRow >= rows) nextRow = rows - 1

    var targetIndex = nextRow * root.cols + nextCol
    if (targetIndex >= count) {
      targetIndex = count - 1
    }

    root.selectedIndex = targetIndex
    resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function toggleFavorite() {
    var count = root.currentEmojisList.length
    if (count === 0 || root.selectedIndex < 0 || root.selectedIndex >= count) return
    var emoji = root.currentEmojisList[root.selectedIndex]
    if (!emoji) return

    var favs = root.stateData.favorites ? root.stateData.favorites.slice() : []
    var idx = favs.indexOf(emoji)
    if (idx !== -1) {
      favs.splice(idx, 1)
    } else {
      favs.push(emoji)
    }

    root.stateData.favorites = favs
    persistState()

    if (root.currentTabIdx === 0 && root.searchQuery.length === 0) {
      root.rebuildGrid()
    }
  }

  function addRecent(emoji) {
    if (!emoji) return
    var recents = root.stateData.recent ? root.stateData.recent.slice() : []
    var idx = recents.indexOf(emoji)
    if (idx !== -1) {
      recents.splice(idx, 1)
    }
    recents.unshift(emoji)
    root.stateData.recent = recents.slice(0, 45)
    persistState()
    if (root.currentTabIdx === 1 && root.searchQuery.length === 0) {
      root.rebuildGrid()
    }
  }

  function getSelectedEmoji() {
    var count = root.currentEmojisList.length
    if (count === 0 || root.selectedIndex < 0 || root.selectedIndex >= count) return ""
    return root.currentEmojisList[root.selectedIndex] || ""
  }

  function applySelected(emoji, closeApp) {
    if (!emoji) return
    addRecent(emoji)

    if (closeApp) {
      root.dismiss()
      Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-menu-emoji-insert", emoji])
    } else {
      // 1. Temporarily release layer keyboard focus so Hyprland routes keystrokes to active target window
      root.keyboardActive = false

      // 2. Multi-paste: copy to clipboard and type via wtype
      Quickshell.execDetached([
        "bash", "-c",
        "printf '%s' \"$1\" | wl-copy --type text/plain --sensitive; sleep 0.02; wtype -M shift -k Insert -m shift 2>/dev/null || wtype \"$1\" 2>/dev/null || true",
        "_",
        emoji
      ])

      // 3. Restore layer keyboard focus after typing completes
      restoreFocusTimer.restart()
    }
  }

  function copySelected(emoji) {
    if (!emoji) return
    addRecent(emoji)
    Quickshell.execDetached(["bash", "-c", "printf '%s' \"$1\" | wl-copy --type text/plain --sensitive", "_", emoji])
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadState(text())
    onLoadFailed: legacyStateFile.reload()
    onFileChanged: reload()
  }

  FileView {
    id: legacyStateFile
    path: root.legacyStatePath
    watchChanges: false
    printErrors: false
    onLoaded: root.loadLegacyState(text())
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-emojis"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened && root.keyboardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          // --- SEARCH / INSERT MODE ---
          if (root.searchMode) {
            if (event.key === Qt.Key_Escape) {
              root.searchMode = false
              event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
              if (root.searchQuery.length > 0) {
                root.searchQuery = root.searchQuery.substring(0, root.searchQuery.length - 1)
                root.selectedIndex = 0
                root.rebuildGrid()
              } else {
                root.searchMode = false
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) {
              root.moveSelection(1, 0)
              event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) {
              root.moveSelection(-1, 0)
              event.accepted = true
            } else if (event.key === Qt.Key_Left) {
              root.moveSelection(0, -1)
              event.accepted = true
            } else if (event.key === Qt.Key_Right) {
              root.moveSelection(0, 1)
              event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
              root.toggleFavorite()
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              var em = root.getSelectedEmoji()
              if (em) root.applySelected(em, false)
              event.accepted = true
            } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
              root.searchQuery += event.text
              root.selectedIndex = 0
              root.rebuildGrid()
              event.accepted = true
            }
            return
          }

          // --- NORMAL / VIM MODE ---
          if (event.key === Qt.Key_Escape) {
            if (root.searchQuery.length > 0) {
              root.searchQuery = ""
              root.selectedIndex = 0
              root.rebuildGrid()
            } else {
              root.dismiss()
            }
            event.accepted = true
          } else if (event.key === Qt.Key_Colon || event.key === Qt.Key_Slash || event.text === ":" || event.text === "/") {
            root.searchMode = true
            event.accepted = true
          } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
            root.moveSelection(0, -1)
            event.accepted = true
          } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
            root.moveSelection(0, 1)
            event.accepted = true
          } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            root.moveSelection(-1, 0)
            event.accepted = true
          } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            root.moveSelection(1, 0)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.moveSelection(-5, 0)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.moveSelection(5, 0)
            event.accepted = true
          } else if (event.key === Qt.Key_A) {
            root.changeTab(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_D) {
            root.changeTab(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Tab) {
            root.toggleFavorite()
            event.accepted = true
          } else if (event.key === Qt.Key_Y) {
            var emYank = root.getSelectedEmoji()
            if (emYank) root.copySelected(emYank)
            event.accepted = true
          } else if (event.key === Qt.Key_Space) {
            var emSpace = root.getSelectedEmoji()
            if (emSpace) root.applySelected(emSpace, true)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            var emEnter = root.getSelectedEmoji()
            if (emEnter) root.applySelected(emEnter, false)
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.space(8)

        // 1. Header (Tabs OR Search Input)
        Rectangle {
          width: parent.width
          height: Style.space(48)
          radius: root.cornerRadius
          color: Color.menu.subtleBackground || "transparent"

          // --- Tabs Mode ---
          Row {
            visible: !root.searchMode && root.searchQuery.length === 0
            anchors.centerIn: parent
            spacing: Style.space(6)

            Repeater {
              model: EmojiData.TAB_ICONS

              Rectangle {
                required property int index
                required property string modelData

                readonly property bool isActive: index === root.currentTabIdx

                width: Style.space(38)
                height: Style.space(38)
                radius: Style.cornerRadius
                color: isActive
                  ? (Color.accent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28) : Qt.rgba(1, 1, 1, 0.22))
                  : (tabHover.containsMouse ? (Color.menu.subtleBackground || Qt.rgba(1, 1, 1, 0.08)) : "transparent")
                border.color: isActive ? (Color.accent || root.selectedText) : "transparent"
                border.width: isActive ? Style.space(1.5) : 0

                Text {
                  anchors.centerIn: parent
                  text: parent.modelData
                  font.family: root.emojiFont
                  font.pixelSize: isActive ? Style.space(22) : Style.space(18)
                }

                MouseArea {
                  id: tabHover
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectTab(index)
                }
              }
            }
          }

          // --- Search Mode / Active Filter View ---
          Item {
            visible: root.searchMode || root.searchQuery.length > 0
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)

            Row {
              anchors.left: parent.left
              anchors.right: escHint.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ":"
                color: Color.accent || root.selectedText
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.searchQuery.length > 0 ? root.searchQuery : (root.searchMode ? "Type to search (español / english / fuzzy)..." : "")
                color: root.foreground
                opacity: root.searchQuery.length > 0 ? 1.0 : 0.4
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }

              // Blinking cursor in search mode
              Rectangle {
                visible: root.searchMode
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(2)
                height: Style.space(18)
                color: root.foreground

                SequentialAnimation on opacity {
                  loops: Animation.Infinite
                  running: root.searchMode
                  NumberAnimation { to: 0; duration: 500 }
                  NumberAnimation { to: 1; duration: 500 }
                }
              }
            }

            Text {
              id: escHint
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              text: root.searchMode ? "[Esc] Normal mode" : "[Esc] Clear search"
              color: root.foreground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // 2. Grid Content Area (Ultra-fast direct JS Array binding)
        Item {
          width: parent.width
          height: parent.height - Style.space(48) - Style.space(64) - Style.space(16)

          GridView {
            id: resultGrid
            anchors.fill: parent
            model: root.currentEmojisList
            clip: true
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              required property int index
              required property string modelData

              readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex

              width: root.cellWidth
              height: root.cellHeight
              radius: root.cornerRadius
              color: hasCursor
                ? (Color.accent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.2))
                : "transparent"
              border.color: hasCursor ? (Color.accent || root.selectedText) : "transparent"
              border.width: hasCursor ? Style.space(2) : 0

              Behavior on color { ColorAnimation { duration: 70 } }
              Behavior on border.color { ColorAnimation { duration: 70 } }

              Text {
                text: parent.modelData
                font.family: root.emojiFont
                font.pixelSize: Style.font.display
                scale: parent.hasCursor ? 1.15 : 1.0
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Behavior on scale { NumberAnimation { duration: 70 } }
              }

              MouseArea {
                id: delegateMouse
                property real lastX: -1
                property real lastY: -1

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPositionChanged: function(mouse) {
                  if (lastX >= 0 && lastY >= 0) {
                    var dx = Math.abs(mouse.x - lastX)
                    var dy = Math.abs(mouse.y - lastY)
                    // Only update selection if mouse is physically moved by user
                    if (dx >= 2 || dy >= 2) {
                      root.cursorActive = true
                      root.selectedIndex = index
                    }
                  }
                  lastX = mouse.x
                  lastY = mouse.y
                }

                onExited: {
                  lastX = -1
                  lastY = -1
                }

                onClicked: {
                  root.selectedIndex = index
                  root.applySelected(parent.modelData, true)
                }
              }
            }
          }

          // Empty state placeholder
          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: root.currentEmojisList.length === 0

            Text {
              text: root.searchQuery.length > 0 ? "🔍" : (root.currentTabIdx === 0 ? "⭐" : "🕒")
              font.family: root.emojiFont
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }

            Text {
              text: root.searchQuery.length > 0
                ? "No emojis matching “" + root.searchQuery + "”"
                : (root.currentTabIdx === 0
                    ? "Press [Tab] on any emoji to add to Favorites!"
                    : "Recently typed emojis will show up here!")
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }
          }
        }

        // 3. Footer (Visual Hints & Status)
        Rectangle {
          width: parent.width
          height: Style.space(64)
          radius: root.cornerRadius
          color: Color.menu.subtleBackground || "transparent"

          Column {
            anchors.centerIn: parent
            spacing: Style.space(3)
            width: parent.width - Style.space(16)

            Text {
              readonly property string currentEmoji: root.getSelectedEmoji()
              readonly property string emojiName: EmojiData.getEmojiName(currentEmoji)
              readonly property string catName: root.searchQuery.length > 0 ? ("Search: “" + root.searchQuery + "” (" + root.currentEmojisList.length + " results)") : (EmojiData.TAB_NAMES[root.currentTabIdx] || "")
              text: currentEmoji
                ? (emojiName ? (currentEmoji + "  " + emojiName + "  •  " + catName) : (currentEmoji + "  •  " + catName))
                : catName
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              anchors.horizontalCenter: parent.horizontalCenter
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.searchMode
                ? "Type to filter  •  [Esc] Normal Mode"
                : "[:] Search  •  [hjkl] Move  •  [a/d] Tabs  •  [Tab] Fav"
              color: root.searchMode ? root.selectedText : root.foreground
              opacity: root.searchMode ? 0.9 : 0.65
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
              horizontalAlignment: Text.AlignHCenter
              anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
              text: root.searchMode
                ? "[Enter] Select & Insert  •  [y] Copy"
                : "[Enter] Multi-Paste  •  [Space] Paste & Close  •  [y] Copy"
              color: root.searchMode ? root.selectedText : root.foreground
              opacity: root.searchMode ? 0.9 : 0.65
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
              horizontalAlignment: Text.AlignHCenter
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }
      }
    }
  }
}
