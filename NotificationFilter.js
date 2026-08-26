// Notification filter engine for Omarchy.
// Matches incoming notifications against configured rules by app, summary, body, and urgency

var _regexCache = {}

function getCompiledRegex(pattern) {
  var pStr = String(pattern)
  if (_regexCache[pStr] !== undefined) return _regexCache[pStr]
  try {
    _regexCache[pStr] = new RegExp(pStr, "i")
  } catch (e) {
    _regexCache[pStr] = null
  }
  return _regexCache[pStr]
}

function parseFilters(raw) {
  if (!raw) return []
  if (Array.isArray(raw)) return raw
  try {
    var parsed = typeof raw === "string" ? JSON.parse(raw) : raw
    if (Array.isArray(parsed)) return parsed
    if (parsed && Array.isArray(parsed.filters)) return parsed.filters
    if (parsed && Array.isArray(parsed.rules)) return parsed.rules
    return []
  } catch (e) {
    console.warn("NotificationFilter: failed to parse filter rules:", e)
    return []
  }
}

function urgencyName(urgency) {
  if (urgency === 0 || urgency === "0" || urgency === "low") return "low"
  if (urgency === 2 || urgency === "2" || urgency === "critical") return "critical"
  return "normal"
}

function testPattern(pattern, value) {
  if (pattern === undefined || pattern === null || pattern === "") return true
  var target = String(value || "")
  var pStr = String(pattern)
  var re = getCompiledRegex(pStr)
  if (re) return re.test(target)
  return target.toLowerCase().indexOf(pStr.toLowerCase()) !== -1
}

function testUrgency(ruleUrgency, notificationUrgency) {
  if (ruleUrgency === undefined || ruleUrgency === null || ruleUrgency === "" || ruleUrgency === "any") return true
  var notificationStr = urgencyName(notificationUrgency)

  if (Array.isArray(ruleUrgency)) {
    for (var i = 0; i < ruleUrgency.length; i++) {
      var item = ruleUrgency[i]
      if (item === "any" || urgencyName(item) === notificationStr) return true
    }
    return false
  }

  return urgencyName(ruleUrgency) === notificationStr
}

function matchRule(notification, rule) {
  if (!rule || typeof rule !== "object") return false
  var n = notification || {}

  var appPattern = rule.app !== undefined ? rule.app : rule.appName
  if (appPattern !== undefined && !testPattern(appPattern, n.app || n.appName)) {
    return false
  }

  if (rule.summary !== undefined && !testPattern(rule.summary, n.summary)) return false
  if (rule.body !== undefined && !testPattern(rule.body, n.body)) return false
  if (rule.urgency !== undefined && !testUrgency(rule.urgency, n.urgency)) return false

  return true
}

function normalizeAction(action) {
  var a = String(action || "silence").toLowerCase().trim()
  if (a === "block" || a === "drop" || a === "ignore" || a === "delete") return "block"
  if (a === "popup" || a === "show" || a === "allow" || a === "bypass_dnd" || a === "force_popup") return "popup"
  return "silence"
}

function evaluate(notification, rules) {
  var list = parseFilters(rules)
  for (var i = 0; i < list.length; i++) {
    var rule = list[i]
    if (matchRule(notification, rule)) {
      return normalizeAction(rule.action)
    }
  }
  return null
}

function loadFiltersCommand(path) {
  var strPath = String(path || "")
  if (strPath === "") return []

  var maxFilterBytes = 1024 * 1024
  var loadFiltersPy = `
import os
import stat
import sys

path = sys.argv[1]
size_limit = ${maxFilterBytes}
descriptor = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
try:
    stats = os.fstat(descriptor)
    if stat.S_ISREG(stats.st_mode) and stats.st_size <= size_limit:
        sys.stdout.buffer.write(os.read(descriptor, size_limit))
finally:
    os.close(descriptor)
`

  return [
    "/usr/bin/timeout",
    "--signal=KILL",
    "1",
    "/usr/bin/python3",
    "-I",
    "-c",
    loadFiltersPy,
    strPath
  ]
}

if (typeof module !== "undefined") {
  module.exports = {
    parseFilters: parseFilters,
    urgencyName: urgencyName,
    testPattern: testPattern,
    testUrgency: testUrgency,
    matchRule: matchRule,
    normalizeAction: normalizeAction,
    evaluate: evaluate,
    loadFiltersCommand: loadFiltersCommand
  }
}
