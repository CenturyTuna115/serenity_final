import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:video_player/video_player.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({Key? key}) : super(key: key);

  @override
  _EducationScreenState createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref('administrator/videos');
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    try {
      print('Starting to fetch videos...');

      final dbSnapshot = await _dbRef.get();

      if (!dbSnapshot.exists) {
        print('No video details found in database');
        setState(() {
          _isLoading = false;
          _videos = [];
        });
        return;
      }

      final videoDetails = dbSnapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> videos = [];

      for (var entry in videoDetails.entries) {
        try {
          final key = entry.key;
          final details = entry.value as Map<dynamic, dynamic>;

          // Get the video URL using the correct key 'videoUrl'
          final videoUrl = details['videoUrl'] as String?;

          print('Processing video with key: $key');
          print('Video details: $details');

          if (videoUrl != null && videoUrl.isNotEmpty) {
            videos.add({
              'url': videoUrl,
              'title': details['title'] ?? 'Untitled Video',
              'details': details['details'] ?? 'No description available',
            });

            print('Successfully added video with title: ${details['title']}');
          } else {
            print('No videoUrl found for video with key: $key');
          }
        } catch (e) {
          print('Error processing video details: $e');
          continue;
        }
      }

      print('Final videos count: ${videos.length}');

      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _fetchVideos: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading videos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Educational Videos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchVideos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No videos available'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchVideos,
                        child: const Text('Retry Loading Videos'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    return VideoCard(
                      videoUrl: _videos[index]['url'],
                      title: _videos[index]['title'],
                      description: _videos[index]['details'],
                    );
                  },
                ),
    );
  }
}

class VideoCard extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String description;

  const VideoCard({
    Key? key,
    required this.videoUrl,
    required this.title,
    required this.description,
  }) : super(key: key);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video player
          AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoPlayer(_controller),
          ),
          // Video info
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.description,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          // Play/pause controls
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
