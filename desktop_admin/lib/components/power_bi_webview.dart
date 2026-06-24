import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

class PowerBiWebView extends StatefulWidget {
  final String embedUrl;

  const PowerBiWebView({super.key, required this.embedUrl});

  @override
  State<PowerBiWebView> createState() => _PowerBiWebViewState();
}

class _PowerBiWebViewState extends State<PowerBiWebView> {
  final _controller = WebviewController();
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      // Initialise le contrôleur Edge WebView2
      await _controller.initialize();
      // Configure la couleur de fond en blanc ou transparent
      await _controller.setBackgroundColor(Colors.transparent);
      // Charge l'URL Power BI
      await _controller.loadUrl(widget.embedUrl);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Erreur d\'initialisation WebView : $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
              const SizedBox(height: 16),
              Text(
                'Impossible de charger le tableau de bord Power BI.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vérifiez que le runtime Microsoft Edge WebView2 est installé sur votre ordinateur.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Connexion à Power BI Cloud...',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Webview(_controller),
      ),
    );
  }
}
