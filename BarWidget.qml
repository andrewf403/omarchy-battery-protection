import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "andrewf.battery-protection"

  property bool available: false
  property bool protectedState: false
  property bool busy: false
  property int chargeLimit: 0
  property string errorText: ""
  property bool iconOverrideActive: false
  property bool iconOverrideValue: false

  readonly property string helperPath: decodeURIComponent(
    Qt.resolvedUrl("battery-protection").toString().replace(/^file:\/\//, ""))
  readonly property string protectedIcon: "󱞜"
  readonly property string unprotectedIcon: "󱞝"
  readonly property bool iconVisible: iconOverrideActive
    ? iconOverrideValue
    : setting("showIcon", false) === true
  readonly property string tooltip: {
    if (busy) return "Updating battery protection…"
    if (errorText !== "") return "Battery protection error · " + errorText
    if (!available) return "Battery protection unavailable"
    if (protectedState)
      return "Battery protection enabled · " + chargeLimit + "% maximum · Click to disable"
    return "Battery protection disabled · Click to enable " + chargeLimit + "% limit"
  }

  function parseStatus(raw) {
    var values = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var tab = lines[i].indexOf("\t")
      if (tab > 0) values[lines[i].substring(0, tab)] = lines[i].substring(tab + 1).trim()
    }

    available = values.available === "1"
    protectedState = values.enabled === "1"
    if (values.limit !== undefined) chargeLimit = Number(values.limit)
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function toggleProtection() {
    if (!available || busy) return
    busy = true
    errorText = ""
    toggleProc.running = true
  }

  function parseBoolean(value) {
    var normalized = String(value || "").trim().toLowerCase()
    if (["1", "true", "yes", "on", "show", "visible"].indexOf(normalized) !== -1) return true
    if (["0", "false", "no", "off", "hide", "hidden"].indexOf(normalized) !== -1) return false
    return null
  }

  function persistIconVisibility(value) {
    if (iconSettingsProc.running) return "busy"
    iconOverrideValue = value
    iconOverrideActive = true
    iconSettingsProc.command = [
      "omarchy", "bar", "set", root.moduleName, "showIcon",
      value ? "true" : "false", "--json"
    ]
    iconSettingsProc.running = true
    return value ? "showing" : "hiding"
  }

  visible: available && iconVisible
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  Component.onCompleted: refresh()

  IpcHandler {
    target: root.moduleName

    function refresh(): void {
      root.broadcast("refresh")
    }

    function getIconVisible(): string { return root.iconVisible ? "true" : "false" }
    function setIconVisible(value: string): string {
      var parsed = root.parseBoolean(value)
      return parsed === null
        ? "value must be true or false"
        : root.persistIconVisibility(parsed)
    }
    function showIcon(): string { return root.persistIconVisibility(true) }
    function hideIcon(): string { return root.persistIconVisibility(false) }
    function toggleIcon(): string { return root.persistIconVisibility(!root.iconVisible) }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: [root.helperPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
    stderr: StdioCollector { id: statusErrors; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.available = false
        root.errorText = statusErrors.text.trim() || "Could not read UPower state"
      }
    }
  }

  Process {
    id: toggleProc
    command: [root.helperPath, "toggle"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
    stderr: StdioCollector { id: toggleErrors; waitForEnd: true }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0)
        root.errorText = toggleErrors.text.trim() || "Could not update battery protection"
      root.refresh()
    }
  }

  Process {
    id: iconSettingsProc
    stderr: StdioCollector { id: iconSettingsErrors; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.iconOverrideActive = false
        root.errorText = iconSettingsErrors.text.trim() || "Could not save the bar icon setting"
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.protectedState ? root.protectedIcon : root.unprotectedIcon
    active: root.protectedState
    useActiveColor: false
    tooltipText: root.tooltip
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.toggleProtection()
    }
  }
}
