import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({Key? key}) : super(key: key);

  @override
  _EducationScreenState createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<String> _videoUrls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    try {
      final ref = _storage.ref('videos');
      final result = await ref.listAll();

      List<String> urls = [];
      for (var item in result.items) {
        final url = await item.getDownloadURL();
        urls.add(url);
      }

      setState(() {
        _videoUrls = urls;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading videos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Educational Videos'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videoUrls.isEmpty
              ? const Center(child: Text('No videos available'))
              : ListView.builder(
                  itemCount: _videoUrls.length,
                  itemBuilder: (context, index) {
                    return VideoCard(videoUrl: _videoUrls[index]);
                  },
                ),
    );
  }
}

class VideoCard extends StatefulWidget {
  final String videoUrl;

  const VideoCard({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoCardState createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoPlayer(_controller),
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _isPlaying = !_isPlaying;
                _isPlaying ? _controller.play() : _controller.pause();
              });
            },
          ),
        ],
      ),
    );
  }
}
