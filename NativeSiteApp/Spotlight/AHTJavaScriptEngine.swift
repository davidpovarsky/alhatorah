import Foundation
import JavaScriptCore

final class AHTJavaScriptEngine {
    private let context: JSContext

    init(refPHP: String) throws {
        guard let context = JSContext() else {
            throw AHTJavaScriptEngineError.couldNotCreateContext
        }
        self.context = context

        var capturedException: JSValue?
        context.exceptionHandler = { _, exception in
            capturedException = exception
        }

        context.evaluateScript(Self.environmentScript)
        try Self.throwIfNeeded(capturedException)

        let cleanedRef = refPHP.replacingOccurrences(of: "\u{feff}", with: "")
        context.evaluateScript("""
        var aht = window.aht || {};
        var dummyToWorkAroundHashBug = 0;
        \(cleanedRef)
        window.aht = aht;
        """)
        try Self.throwIfNeeded(capturedException)

        context.evaluateScript(Self.postLoadScript)
        try Self.throwIfNeeded(capturedException)
    }

    var branches: [String: Any] {
        dictionary(from: context.evaluateScript("aht && aht.texts && aht.texts.tree ? aht.texts.tree.branches : {}"))
    }

    var data: [String: Any] {
        dictionary(from: context.evaluateScript("aht && aht.texts ? aht.texts.data : {}"))
    }

    var aliasesMap: [String: Any] {
        dictionary(from: context.evaluateScript("aht && aht.texts ? aht.texts.mapTitleStartToSource : {}"))
    }

    func expandedSectionCount(for id: String) -> Int {
        let value = context.objectForKeyedSubscript("__ahtExpandedSectionCount")?.call(withArguments: [id])
        return Int(value?.toInt32() ?? 0)
    }

    func resolveReferenceURL(candidates: [String]) -> URL? {
        let value = context.objectForKeyedSubscript("__ahtResolveReferenceURL")?.call(withArguments: [candidates])
        guard let string = value?.toString(), !string.isEmpty else { return nil }
        return URL(string: string)
    }

    private func dictionary(from value: JSValue?) -> [String: Any] {
        guard let raw = value?.toDictionary() else { return [:] }
        return normalizeDictionary(raw)
    }

    private func normalizeDictionary(_ raw: [AnyHashable: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in raw {
            result[String(describing: key)] = normalize(value)
        }
        return result
    }

    private func normalize(_ value: Any) -> Any {
        if let dictionary = value as? [AnyHashable: Any] {
            return normalizeDictionary(dictionary)
        }
        if let dictionary = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, value) in dictionary {
                result[key] = normalize(value)
            }
            return result
        }
        if let array = value as? [Any] {
            return array.map { normalize($0) }
        }
        return value
    }

    private static func throwIfNeeded(_ exception: JSValue?) throws {
        if let exception, !exception.isUndefined {
            throw AHTJavaScriptEngineError.javascriptException(exception.toString())
        }
    }

    private static let environmentScript = #"""
    var console = {
      log: function(){}, warn: function(){}, error: function(){}, debug: function(){}
    };

    var navigator = { userAgent: "Mozilla/5.0 iPhone AlHaTorah" };
    var location = { hostname: "www.alhatorah.org", host: "www.alhatorah.org", href: "https://mg.alhatorah.org/" };
    var localStorage = { getItem: function(){ return null; }, setItem: function(){}, removeItem: function(){} };

    var window = {
      console: console,
      navigator: navigator,
      location: location,
      localStorage: localStorage,
      open: function(){ return null; }
    };
    window.window = window;
    window.ahtTextDatabaseContents = {};

    var document = {
      createElement: function(){ return { href: "", style: {}, setAttribute: function(){}, appendChild: function(){} }; },
      getElementById: function(){ return null; },
      body: {}
    };
    window.document = document;

    function setTimeout(fn) { if (typeof fn === "function") fn(); return 0; }
    function clearTimeout() {}
    window.setTimeout = setTimeout;
    window.clearTimeout = clearTimeout;
    window.alert = function(){};
    var alert = window.alert;

    function __isPlainObject(value) {
      return value && Object.prototype.toString.call(value) === "[object Object]";
    }

    function __shallowExtend(target) {
      target = target || {};
      for (var i = 1; i < arguments.length; i++) {
        var source = arguments[i];
        if (!source) continue;
        for (var key in source) if (Object.prototype.hasOwnProperty.call(source, key)) target[key] = source[key];
      }
      return target;
    }

    function __deepExtend(target) {
      target = target || {};
      for (var i = 1; i < arguments.length; i++) {
        var source = arguments[i];
        if (!source) continue;
        for (var key in source) {
          if (!Object.prototype.hasOwnProperty.call(source, key)) continue;
          var value = source[key];
          if (Array.isArray(value)) target[key] = __deepExtend([], value);
          else if (__isPlainObject(value)) target[key] = __deepExtend(__isPlainObject(target[key]) ? target[key] : {}, value);
          else target[key] = value;
        }
      }
      return target;
    }

    function __jqueryObject() {
      var obj = { length: 0 };
      var methods = [
        "each", "css", "attr", "removeAttr", "html", "text", "before", "after",
        "append", "appendTo", "prepend", "prependTo", "dialog", "on", "off", "change",
        "click", "keydown", "keyup", "trigger", "triggerHandler", "tooltip", "autocomplete",
        "children", "closest", "find", "parent", "parents", "next", "prev", "siblings",
        "first", "last", "eq", "filter", "not", "addClass", "removeClass", "toggleClass",
        "remove", "hide", "show", "empty", "focus", "blur", "mousedown"
      ];
      for (var i = 0; i < methods.length; i++) obj[methods[i]] = function(){ return obj; };
      obj.val = function(){ return ""; };
      obj.data = function(){ return { _renderItem: null }; };
      obj.hasClass = function(){ return false; };
      obj.is = function(){ return false; };
      obj.width = function(){ return 0; };
      obj.height = function(){ return 0; };
      obj.outerWidth = function(){ return 0; };
      obj.outerHeight = function(){ return 0; };
      obj.position = function(){ return { left: 0, top: 0 }; };
      obj.offset = function(){ return { left: 0, top: 0 }; };
      return obj;
    }

    function $(selector) { return __jqueryObject(); }
    $.fn = {};
    $.each = function(obj, callback) {
      if (!obj) return obj;
      if (Array.isArray(obj) || typeof obj.length === "number") {
        for (var i = 0; i < obj.length; i++) if (callback.call(obj[i], i, obj[i]) === false) break;
      } else {
        for (var key in obj) if (Object.prototype.hasOwnProperty.call(obj, key)) {
          if (callback.call(obj[key], key, obj[key]) === false) break;
        }
      }
      return obj;
    };
    $.extend = function() {
      var deep = false, target, start;
      if (typeof arguments[0] === "boolean") { deep = arguments[0]; target = arguments[1] || {}; start = 2; }
      else { target = arguments[0] || {}; start = 1; }
      var args = [target];
      for (var i = start; i < arguments.length; i++) args.push(arguments[i]);
      return deep ? __deepExtend.apply(null, args) : __shallowExtend.apply(null, args);
    };
    $.merge = function(first, second) { first = first || []; second = second || []; for (var i = 0; i < second.length; i++) first.push(second[i]); return first; };
    $.map = function(array, callback) { var result = []; if (!array) return result; for (var i = 0; i < array.length; i++) { var value = callback(array[i], i); if (value != null) result.push(value); } return result; };
    $.grep = function(array, callback) { return (array || []).filter(callback); };
    $.inArray = function(item, array) { return (array || []).indexOf(item); };
    $.isArray = Array.isArray;
    $.isPlainObject = __isPlainObject;
    $.isEmptyObject = function(obj) { return !obj || Object.keys(obj).length === 0; };
    $.trim = function(value) { return String(value == null ? "" : value).trim(); };
    $.parseJSON = JSON.parse;
    $.proxy = function(fn, context) { return fn.bind(context); };
    $.ajax = function(){ throw new Error("AJAX is disabled in native parser wrapper"); };
    $.getJSON = $.ajax;
    var jQuery = $;
    window.$ = $;
    window.jQuery = $;
    """#

    private static let postLoadScript = #"""
    if (!aht.texts) throw new Error("ref.php did not create aht.texts");
    aht.__nativeReady = false;
    aht.texts.inReferenceServer = true;
    aht.texts.algorithm = "C";
    if (!aht.texts.dialog) aht.texts.dialog = {};
    if (!aht.texts.dialog.mode) aht.texts.dialog.mode = "browser";
    if (aht.texts.tree) aht.texts.tree.complete = function(){};
    if (typeof aht.texts.initRef === "function") aht.texts.initRef();
    if (typeof aht.texts.setRefStrings === "function") aht.texts.setRefStrings("he");
    if (typeof aht.texts.buildMapTitleStartToSource === "function") {
      aht.texts.buildMapTitleStartToSource(function(){ aht.__nativeReady = true; });
    } else {
      aht.__nativeReady = true;
    }

    function __ahtExpandedSectionCount(id) {
      try {
        if (!aht.texts || !aht.texts.database || typeof aht.texts.database.getExpandedListOfSections !== "function") return 0;
        var expanded = aht.texts.database.getExpandedListOfSections(id);
        if (!expanded) return 0;
        var count = 0;
        if (Array.isArray(expanded)) {
          for (var i = 0; i < expanded.length; i++) {
            var sub = expanded[i];
            if (!sub || typeof sub !== "object") continue;
            Object.keys(sub).forEach(function(key){ if (key && key !== "nosections") count++; });
          }
          return count;
        }
        if (typeof expanded === "object") {
          Object.keys(expanded).forEach(function(key){ if (key && key !== "nosections") count++; });
          return count;
        }
      } catch (e) {}
      return 0;
    }

    function __ahtBuildAlHaTorahUrl(ref) {
      if (!ref || !ref.url) return "";
      var host = ref.mgType === "Tanakh" ? "mg" : String(ref.mgType || "library").toLowerCase();
      var cleanPath = String(ref.url).replace(/\$\$.*/, "").replace(/ /g, "_");
      return "https://" + host + ".alhatorah.org/#!" + encodeURI(cleanPath);
    }

    function __ahtResolveReferenceURL(candidates) {
      if (!Array.isArray(candidates)) return "";
      var seen = {};
      for (var i = 0; i < candidates.length; i++) {
        var query = String(candidates[i] || "").trim();
        if (!query || seen[query]) continue;
        seen[query] = true;
        try {
          var ref = aht.texts.parseInputRef(query, false);
          var url = __ahtBuildAlHaTorahUrl(ref);
          if (url) return url;
        } catch (e) {}
      }
      return "";
    }
    """#
}

enum AHTJavaScriptEngineError: LocalizedError {
    case couldNotCreateContext
    case javascriptException(String?)

    var errorDescription: String? {
        switch self {
        case .couldNotCreateContext:
            return "Could not create JavaScriptCore context."
        case .javascriptException(let message):
            return message ?? "JavaScriptCore failed while reading ref.php."
        }
    }
}
