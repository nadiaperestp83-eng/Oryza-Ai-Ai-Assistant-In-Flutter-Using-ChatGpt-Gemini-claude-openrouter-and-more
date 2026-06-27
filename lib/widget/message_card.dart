import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../helper/global.dart';
import '../model/message.dart';

class MessageCard extends StatelessWidget {
  final Message message;

  const MessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return message.msgType == MessageType.bot
        ? _BotMessage(message: message)
        : _UserMessage(message: message);
  }
}

class _UserMessage extends StatelessWidget {
  final Message message;
  const _UserMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: mq.width * .75),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE67E22),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              message.msg,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotMessage extends StatelessWidget {
  final Message message;
  const _BotMessage({required this.message});

  bool get _isGeneratingVideo =>
      message.videoUrl == '' && message.msg.isEmpty;

  bool get _hasVideo =>
      message.videoUrl != null && message.videoUrl!.isNotEmpty;

  bool get _isGeneratingImage =>
      message.imageBase64 == '' && message.msg.isEmpty;

  bool get _hasImage =>
      message.imageBase64 != null && message.imageBase64!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // Estado "gerando vídeo": só o anel pulsando, sem bolha de texto grande.
    if (_isGeneratingVideo) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24, left: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _PulsingRing(label: 'Gerando vídeo...'),
        ),
      );
    }

    // Estado "gerando imagem": mesmo anel pulsando, texto diferente.
    if (_isGeneratingImage) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24, left: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _PulsingRing(label: 'Gerando imagem...'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: mq.width * .75),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _AssistantLabel(),
                ),
                if (_hasVideo)
                  _VideoPlayerWidget(url: message.videoUrl!)
                else if (_hasImage)
                  _ImageResultWidget(base64Image: message.imageBase64!)
                else if (message.msg.isEmpty)
                  AnimatedTextKit(
                    animatedTexts: [
                      TypewriterAnimatedText(
                        'Buscando...',
                        textStyle: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.white54,
                          height: 1.5,
                        ),
                        speed: const Duration(milliseconds: 50),
                      ),
                    ],
                    repeatForever: true,
                  )
                else
                  Text(
                    message.msg,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.92),
                      height: 1.6,
                    ),
                  ),
                if (message.msg.isNotEmpty && !_hasVideo && !_hasImage)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: message.msg));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Texto copiado'),
                            duration: Duration(seconds: 1),
                            backgroundColor: Color(0xFF1E1E1E),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Anel pulsando exibido enquanto vídeo ou imagem está sendo gerado.
/// Substitui a bolha de texto grande — fica leve e discreto no chat.
class _PulsingRing extends StatefulWidget {
  final String label;
  const _PulsingRing({required this.label});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = 0.8 + (0.3 * (1 - (_controller.value - 0.5).abs() * 2));
            final opacity = 0.4 + (0.6 * (1 - (_controller.value - 0.5).abs() * 2));
            return Opacity(
              opacity: opacity.clamp(0.3, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE67E22),
                      width: 3,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}

/// Player de vídeo embutido na bolha de resposta do assistente.
class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  const _VideoPlayerWidget({required this.url});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {
        if (mounted) setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Text(
        'Não foi possível carregar o vídeo.',
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white54),
      );
    }

    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFE67E22),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(c),
            GestureDetector(
              onTap: () {
                setState(() {
                  c.value.isPlaying ? c.pause() : c.play();
                });
              },
              child: AnimatedOpacity(
                opacity: c.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Imagem gerada exibida na bolha de resposta, com botões para
/// salvar na galeria e compartilhar — mesma lógica do ImageController.
class _ImageResultWidget extends StatefulWidget {
  final String base64Image;
  const _ImageResultWidget({required this.base64Image});

  @override
  State<_ImageResultWidget> createState() => _ImageResultWidgetState();
}

class _ImageResultWidgetState extends State<_ImageResultWidget> {
  bool _busy = false;

  Future<File> _writeTempFile() async {
    final bytes = base64Decode(widget.base64Image);
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/ai_image_${DateTime.now().millisecondsSinceEpoch}.png')
        .writeAsBytes(bytes);
  }

  Future<void> _download(BuildContext context) async {
    setState(() => _busy = true);
    try {
      final file = await _writeTempFile();
      await ImageGallerySaverPlus.saveFile(file.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem salva na galeria!'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1E1E1E),
          ),
        );
      }
    } catch (e) {
      log('downloadImageE: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar imagem!'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1E1E1E),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final file = await _writeTempFile();
      await Share.shareXFiles([XFile(file.path)], text: 'Imagem criada com IA!');
    } catch (e) {
      log('shareImageE: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Uint8List bytes;
    try {
      bytes = base64Decode(widget.base64Image);
    } catch (_) {
      return Text(
        'Não foi possível carregar a imagem.',
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: _busy ? null : () => _download(context),
              icon: const Icon(Icons.save_alt_rounded, color: Color(0xFFE67E22), size: 22),
            ),
            IconButton(
              onPressed: _busy ? null : _share,
              icon: const Icon(Icons.share_rounded, color: Color(0xFFE67E22), size: 22),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE67E22)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AssistantLabel extends StatelessWidget {
  const _AssistantLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('✨', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        Text(
          'Assistente',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
