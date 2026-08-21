import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "NotificationFilter.js" as NotificationFilter

BarWidget {
  id: root
  moduleName: "filter.notifications"

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/omarchy/"
  readonly property string filtersPath: stateDir + "filter.notifications/filters.json"

  property var rules: []
  property int editingIndex: -1 // -1: none, -2: adding new, >= 0: editing index
  property int confirmingDeleteIndex: -1

  Timer {
    id: confirmDeleteTimer 
    interval: 4000
    onTriggered: root.confirmingDeleteIndex = -1
  }

  // Form fields for adding/editing
  property string formAction: "silence"
  property string formApp: ""
  property string formSummary: ""
  property string formBody: ""
  property string formUrgency: "any"
  property string formDescription: ""
  property string formError: ""

  FileView {
    id: filtersFile
    path: root.filtersPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.rules = NotificationFilter.parseFilters(text())
    onLoadFailed: root.rules = []
    onFileChanged: reload()
  }

  Component.onCompleted: {
    filtersFile.reload()
  }

  function saveRules(newRules) {
    root.rules = newRules
    filtersFile.setText(JSON.stringify(newRules, null, 2) + "\n")
  }

  function startAdd() {
    confirmingDeleteIndex = -1
    confirmDeleteTimer.stop()
    formAction = "silence"
    formApp = ""
    formSummary = ""
    formBody = ""
    formUrgency = "any"
    formDescription = ""
    formError = ""
    editingIndex = -2
  }

  function startEdit(index) {
    confirmingDeleteIndex = -1
    confirmDeleteTimer.stop()
    if (index < 0 || index >= rules.length) return
    var r = rules[index] || {}
    formAction = r.action || "silence"
    formApp = r.app !== undefined ? String(r.app) : (r.appName !== undefined ? String(r.appName) : "")
    formSummary = r.summary !== undefined ? String(r.summary) : ""
    formBody = r.body !== undefined ? String(r.body) : ""
    formUrgency = r.urgency !== undefined ? String(r.urgency) : "any"
    formDescription = r.description !== undefined ? String(r.description) : ""
    formError = ""
    editingIndex = index
  }

  function cancelEdit() {
    confirmingDeleteIndex = -1
    confirmDeleteTimer.stop()
    editingIndex = -1
    formError = ""
  }

  function submitForm() {
    var appTrim = formApp.trim()
    var sumTrim = formSummary.trim()
    var bodyTrim = formBody.trim()
    var urgTrim = formUrgency.trim()

    if (!appTrim && !sumTrim && !bodyTrim && (!urgTrim || urgTrim === "any")) {
      formError = "Specify at least one condition (App, Summary, Body, or Urgency)"
      return
    }

    var rule = {
      action: formAction
    }
    if (formDescription.trim()) rule.description = formDescription.trim()
    if (appTrim) rule.app = appTrim
    if (sumTrim) rule.summary = sumTrim
    if (bodyTrim) rule.body = bodyTrim
    if (urgTrim && urgTrim !== "any") rule.urgency = urgTrim

    var updated = []
    for (var i = 0; i < root.rules.length; i++) updated.push(root.rules[i])

    if (editingIndex === -2) {
      updated.unshift(rule)
    } else if (editingIndex >= 0 && editingIndex < updated.length) {
      updated[editingIndex] = rule
    }

    saveRules(updated)
    editingIndex = -1
    formError = ""
  }

  function deleteRule(index) {
    confirmingDeleteIndex = -1
    confirmDeleteTimer.stop()
    if (index < 0 || index >= rules.length) return
    var updated = []
    for (var i = 0; i < root.rules.length; i++) {
      if (i !== index) updated.push(root.rules[i])
    }
    saveRules(updated)
    if (editingIndex === index) editingIndex = -1
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Taskbar icon button
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "Notification Filters"
    iconComponent: Component {
      Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -1
        text: "󰈲"
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.bar.iconFont
        renderType: Text.NativeRendering
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
    onPressed: function(b) {
      panel.open = !panel.open
    }
  }

  // Pop-up Panel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)
    onOpenChanged: {
      if (!open) {
        root.confirmingDeleteIndex = -1
        confirmDeleteTimer.stop()
        root.cancelEdit()
      }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: {
        if (root.editingIndex !== -1) root.cancelEdit()
        else panel.open = false
      }

      ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(12)

        // Header
        Item {
          Layout.fillWidth: true
          implicitHeight: Math.max(headerLeft.implicitHeight, headerButton.implicitHeight)

          Row {
            id: headerLeft
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            Text {
              text: "󰈲"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.heading
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              spacing: Style.space(2)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                text: "Notification Filters"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                text: root.rules.length + (root.rules.length === 1 ? " active rule" : " active rules")
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }

          Button {
            id: headerButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.editingIndex === -1
            text: "Add Rule"
            iconText: "󰐕"
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            accent: Color.accent
            bordered: true
            onClicked: root.startAdd()
          }
        }

        PanelSeparator {
          Layout.fillWidth: true
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        // Form View (Add / Edit)
        ColumnLayout {
          visible: root.editingIndex !== -1
          Layout.fillWidth: true
          spacing: Style.space(10)

          Text {
            text: root.editingIndex === -2 ? "New Filter Rule" : "Edit Filter Rule"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }

          // Action selector
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "ACTION"
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              foreground: root.bar ? root.bar.foreground : Color.foreground
            }

            Dropdown {
              Layout.fillWidth: true
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              value: root.formAction
              options: [
                { value: "silence", label: "󰂛 Silence (Save to History, no popup)" },
                { value: "block", label: "󰅙 Block (Drop completely)" },
                { value: "popup", label: "󰂚 Always Popup (Bypass DND)" }
              ]
              onChanged: function(v) { root.formAction = v }
            }
          }

          // App Name
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "APP NAME / REGEX (OPTIONAL)"
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              foreground: root.bar ? root.bar.foreground : Color.foreground
            }

            TextField {
              Layout.fillWidth: true
              placeholderText: "e.g. Spotify, Slack, ^steam_app_.*"
              text: root.formApp
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              onTextChanged: root.formApp = text
            }
          }

          // Summary regex
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "SUMMARY PATTERN / REGEX (OPTIONAL)"
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              foreground: root.bar ? root.bar.foreground : Color.foreground
            }

            TextField {
              Layout.fillWidth: true
              placeholderText: "e.g. .*Daily Standup.*, ^Playing"
              text: root.formSummary
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              onTextChanged: root.formSummary = text
            }
          }

          // Body regex
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "BODY PATTERN / REGEX (OPTIONAL)"
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              foreground: root.bar ? root.bar.foreground : Color.foreground
            }

            TextField {
              Layout.fillWidth: true
              placeholderText: "e.g. .*verification code.*"
              text: root.formBody
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              onTextChanged: root.formBody = text
            }
          }

          // Urgency
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "URGENCY"
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              foreground: root.bar ? root.bar.foreground : Color.foreground
            }

            Dropdown {
              Layout.fillWidth: true
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              value: root.formUrgency
              options: [
                { value: "any", label: "Any Urgency" },
                { value: "low", label: "Low" },
                { value: "normal", label: "Normal" },
                { value: "critical", label: "Critical" }
              ]
              onChanged: function(v) { root.formUrgency = v }
            }
          }

          // Description (optional label)
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "DESCRIPTION (OPTIONAL NOTE)"
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              foreground: root.bar ? root.bar.foreground : Color.foreground
            }

            TextField {
              Layout.fillWidth: true
              placeholderText: "e.g. Mute music notification spam"
              text: root.formDescription
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              onTextChanged: root.formDescription = text
            }
          }

          // Error text if validation fails
          Text {
            visible: root.formError !== ""
            text: root.formError
            color: root.bar ? root.bar.urgent : Color.urgent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            Layout.fillWidth: true
          }

          // Form buttons
          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Style.space(6)
            spacing: Style.space(8)

            Button {
              Layout.fillWidth: true
              text: "Cancel"
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.cancelEdit()
            }

            Button {
              Layout.fillWidth: true
              text: "Save Rule"
              iconText: "󰄬"
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              accent: Color.accent
              bordered: true
              active: true
              onClicked: root.submitForm()
            }
          }
        }

        // Rules List View (when not editing)
        ColumnLayout {
          visible: root.editingIndex === -1
          Layout.fillWidth: true
          spacing: Style.space(8)

          // Empty state
          Text {
            visible: root.rules.length === 0
            text: "No filter rules configured.\nClick '+ Add Rule' to create one."
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            Layout.topMargin: Style.space(12)
            Layout.bottomMargin: Style.space(12)
          }

          // List of rules
          Repeater {
            model: root.rules

            delegate: BorderSurface {
              id: ruleCard
              required property int index
              required property var modelData

              Layout.fillWidth: true
              implicitHeight: ruleRow.implicitHeight + Style.space(16)
              radius: Style.cornerRadius
              color: Qt.rgba(1, 1, 1, 0.03)
              borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)

              readonly property string actionName: NotificationFilter.normalizeAction(modelData && modelData.action)
              readonly property color actionColor: {
                if (actionName === "block") return root.bar ? root.bar.urgent : Color.urgent
                if (actionName === "popup") return Color.accent
                return root.bar ? root.bar.foreground : Color.foreground
              }
              readonly property string actionBadgeText: {
                if (actionName === "block") return "󰅙 Block"
                if (actionName === "popup") return "󰂚 Popup"
                return "󰂛 Silence"
              }

              RowLayout {
                id: ruleRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(10)

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(3)

                  RowLayout {
                    spacing: Style.space(6)

                    // Action badge
                    Rectangle {
                      radius: Style.space(4)
                      color: Qt.rgba(ruleCard.actionColor.r, ruleCard.actionColor.g, ruleCard.actionColor.b, 0.2)
                      border.color: ruleCard.actionColor
                      border.width: 1
                      implicitWidth: badgeText.implicitWidth + Style.space(10)
                      implicitHeight: badgeText.implicitHeight + Style.space(4)

                      Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: ruleCard.actionBadgeText
                        color: ruleCard.actionColor
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    // Description or rule summary
                    Text {
                      Layout.fillWidth: true
                      text: modelData.description || (modelData.app ? ("App: " + modelData.app) : (modelData.summary ? ("Summary: " + modelData.summary) : "Filter Rule"))
                      color: root.bar ? root.bar.foreground : Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                    }
                  }

                  // Conditions detail
                  ColumnLayout {
                    spacing: Style.space(1)
                    Layout.fillWidth: true

                    Text {
                      visible: !!modelData.app
                      text: "App: " + modelData.app
                      color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.35)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Text {
                      visible: !!modelData.summary
                      text: "Summary: " + modelData.summary
                      color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.35)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Text {
                      visible: !!modelData.body
                      text: "Body: " + modelData.body
                      color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.35)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Text {
                      visible: !!modelData.urgency && modelData.urgency !== "any"
                      text: "Urgency: " + modelData.urgency
                      color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.35)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }
                }

                // Edit button
                PanelActionButton {
                  iconText: "󰏫"
                  tooltipText: "Edit rule"
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  foreground: root.bar ? root.bar.foreground : Color.foreground
                  hoverColor: Color.accent
                  onClicked: root.startEdit(ruleCard.index)
                }

                // Delete button
                PanelActionButton {
                  readonly property bool isConfirming: root.confirmingDeleteIndex === ruleCard.index
                  iconText: isConfirming ? "󰋗" : "󰅙"
                  tooltipText: isConfirming ? "Click again to delete" : "Delete rule"
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  foreground: isConfirming ? (root.bar ? root.bar.urgent : Color.urgent) : (root.bar ? root.bar.foreground : Color.foreground)
                  hoverColor: root.bar ? root.bar.urgent : Color.urgent
                  onClicked: {
                    if (isConfirming) {
                      confirmDeleteTimer.stop()
                      root.confirmingDeleteIndex = -1
                      root.deleteRule(ruleCard.index)
                    } else {
                      root.confirmingDeleteIndex = ruleCard.index
                      confirmDeleteTimer.restart()
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
