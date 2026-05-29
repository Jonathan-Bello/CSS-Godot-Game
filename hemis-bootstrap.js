(function () {
  var backendUrl = String(window.HEMIS_BACKEND_URL || window.EMIS_BACKEND_URL || "").replace(/\/+$/, "");
  var localBackendPattern = /^https?:\/\/(?:127\.0\.0\.1|localhost):8080(\/.*)?$/;
  window.HEMIS_PLAYER_API_KEY = String(window.HEMIS_PLAYER_API_KEY || window.EMIS_PLAYER_API_KEY || "");
  window.EMIS_PLAYER_API_KEY = window.HEMIS_PLAYER_API_KEY;

  function rewriteUrl(input) {
    var rawUrl = typeof input === "string" ? input : String(input && input.url ? input.url : input || "");
    if (!backendUrl) return rawUrl;
    var match = rawUrl.match(localBackendPattern);
    if (!match) return rawUrl;
    return backendUrl + (match[1] || "");
  }

  function withApiKeyHeaders(init) {
    var nextInit = Object.assign({}, init || {});
    var headers = new Headers(nextInit.headers || {});
    var playerApiKey = window.HEMIS_PLAYER_API_KEY || window.EMIS_PLAYER_API_KEY;
    if (playerApiKey) {
      headers.set("X-Hemis-Api-Key", playerApiKey);
    }
    nextInit.headers = headers;
    return nextInit;
  }

  function normalizeBackendBody(body) {
    if (!body || typeof body !== "object") return body;
    var reply = typeof body.reply === "string" ? body.reply.trim() : "";
    if (!reply || reply.charAt(0) !== "{") return body;

    try {
      var parsed = JSON.parse(reply);
      var nestedReply = parsed && (
        parsed.reply ||
        parsed.message ||
        parsed.Rippledai ||
        parsed.rippledai
      );
      if (typeof nestedReply === "string" && nestedReply.trim()) {
        body.reply = nestedReply.trim();
      }
    } catch (_error) {}

    return body;
  }

  function enrichRequestBody(init) {
    if (!init || typeof init.body !== "string") return init;
    try {
      var parsed = JSON.parse(init.body);
      if (!parsed.chat_surface) {
        parsed.chat_surface = resolveChatSurfaceFromOverlay();
      }
      init.body = JSON.stringify(parsed);
    } catch (_error) {}
    return init;
  }

  function resolveChatSurfaceFromOverlay() {
    try {
      var frame = document.getElementById("css-game-html-overlay-frame");
      var doc = frame && frame.contentDocument;
      if (doc && (doc.getElementById("hemisPanel") || doc.getElementById("codeInput") || doc.querySelector(".editor-shell"))) {
        return "bullet_creator";
      }
    } catch (_error) {}
    return "general_chat";
  }

  function installFetchPatch() {
    if (!window.fetch || window.__hemisFetchPatchInstalled) return;
    window.__hemisFetchPatchInstalled = true;
    var nativeFetch = window.fetch.bind(window);

    window.fetch = function hemisFetch(input, init) {
      var nextInput = input;
      var nextInit = enrichRequestBody(withApiKeyHeaders(init));
      var nextUrl = rewriteUrl(input);

      if (typeof input === "string" || input instanceof URL) {
        nextInput = nextUrl;
      } else if (input && input.url && nextUrl !== input.url) {
        nextInput = new Request(nextUrl, input);
      }

      return nativeFetch(nextInput, nextInit).then(function (response) {
        if (!String(response.headers.get("content-type") || "").includes("application/json")) {
          return response;
        }

        return response.clone().json().then(function (body) {
          var normalized = normalizeBackendBody(body);
          return new Response(JSON.stringify(normalized), {
            status: response.status,
            statusText: response.statusText,
            headers: response.headers,
          });
        }).catch(function () {
          return response;
        });
      });
    };
  }

  function setApiKey(value) {
    window.HEMIS_PLAYER_API_KEY = String(value || "").trim();
    window.EMIS_PLAYER_API_KEY = window.HEMIS_PLAYER_API_KEY;
    window.dispatchEvent(new CustomEvent("hemis-api-key-updated", {
      detail: { configured: !!window.HEMIS_PLAYER_API_KEY },
    }));
    window.dispatchEvent(new CustomEvent("emis-api-key-updated", {
      detail: { configured: !!window.HEMIS_PLAYER_API_KEY },
    }));
  }

  function showApiKeyPrompt() {
    if (window.__hemisApiKeyPromptShown) return;
    window.__hemisApiKeyPromptShown = true;

    var root = document.createElement("div");
    root.id = "hemis-api-key-bootstrap";
    root.style.cssText = "position:fixed;inset:0;z-index:2147483646;display:grid;place-items:center;background:rgba(2,6,18,.88);color:#fff;font-family:system-ui,-apple-system,Segoe UI,sans-serif;padding:20px;box-sizing:border-box;";
    root.innerHTML = [
      '<form style="width:min(520px,100%);display:grid;gap:12px;background:#111a2f;border:1px solid #314266;border-radius:10px;padding:18px;box-shadow:0 18px 60px rgba(0,0,0,.45)">',
      '<h1 style="font-size:20px;margin:0;color:#ffd57f">Configurar Hemis</h1>',
      '<p style="font-size:14px;line-height:1.45;margin:0;color:#dbe8ff">Ingresa tu API key de Gemini para activar el chat. Se conserva solo en memoria mientras esta pestana siga abierta.</p>',
      '<input name="apiKey" type="password" autocomplete="off" spellcheck="false" placeholder="API key de Gemini" style="width:100%;box-sizing:border-box;background:#070d19;color:#fff;border:1px solid #42577f;border-radius:8px;padding:10px;font-size:14px">',
      '<div style="display:flex;gap:8px;justify-content:flex-end;flex-wrap:wrap">',
      '<button type="button" data-skip style="background:#28364f;color:#fff;border:0;border-radius:8px;padding:9px 12px;font-weight:700;cursor:pointer">Omitir</button>',
      '<button type="submit" style="background:#4a90e2;color:#fff;border:0;border-radius:8px;padding:9px 12px;font-weight:700;cursor:pointer">Usar key</button>',
      '</div>',
      '</form>',
    ].join("");

    function close() {
      if (root.parentNode) root.parentNode.removeChild(root);
    }

    root.querySelector("form").addEventListener("submit", function (event) {
      event.preventDefault();
      setApiKey(root.querySelector("input").value);
      close();
    });
    root.querySelector("[data-skip]").addEventListener("click", close);
    document.addEventListener("DOMContentLoaded", function () {
      document.body.appendChild(root);
      var input = root.querySelector("input");
      if (input) input.focus();
    });
  }

  installFetchPatch();
  showApiKeyPrompt();
  window.setHemisPlayerApiKey = setApiKey;
  window.setEmisPlayerApiKey = setApiKey;
}());
