import SwiftUI
import UIKit
import WebKit

private let respringDocument = """
<!DOCTYPE html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body>
<iframe id="frame" srcdoc="" sandbox="allow-scripts"></iframe>
<script>
const frame = document.getElementById('frame');
const inner = `
<html><body><script>
const container = document.createElement('div');
container.style.cssText = 'perspective:1px;perspective-origin:9999999% 9999999%;';
document.body.appendChild(container);
for (let i = 0; i < 400; i++) {
  const d = document.createElement('div');
  d.style.cssText = 'position:absolute;width:100vw;height:100vh;' +
    'backdrop-filter:blur(120px);-webkit-backdrop-filter:blur(120px);' +
    'transform:translate3d(100000px,100000px,' + i + 'px) rotateY(90deg);';
  container.appendChild(d);
}
setInterval(() => {
  try { navigator.share({ title:'r', text:'r'.repeat(80000) }); } catch (e) {}
  const x = new Uint8Array(1024 * 1024 * 8);
  crypto.getRandomValues(x);
}, 0);
<\\/script></body></html>`;
frame.srcdoc = inner;
</script>
</body>
</html>
"""

struct RespringView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(respringDocument, baseURL: nil)
    }
}