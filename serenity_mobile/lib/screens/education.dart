import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({Key? key}) : super(key: key);

  @override
  _EducationScreenState createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref('administrator/videos');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _videos = [];
  List<String> _userConditions = [];
  bool _isLoading = true;
  // Removed _showAllVideos flag since we're removing the toggle functionality

  @override
  void initState() {
    super.initState();
    _fetchUserConditionsAndVideos();
  }

  Future<void> _fetchUserConditionsAndVideos() async {
    try {
      await _fetchUserConditions();
      await _fetchVideos();
    } catch (e) {
      print('Error in _fetchUserConditionsAndVideos: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _fetchUserConditions() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('No user logged in');
      return;
    }

    try {
      final userRef = FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}/conditions');
      final snapshot = await userRef.get();

      if (snapshot.exists) {
        var conditionData = snapshot.value;
        if (conditionData is List) {
          _userConditions = List<String>.from(conditionData);
        } else if (conditionData is Map) {
          _userConditions = List<String>.from(conditionData.values);
        }
        print('User conditions: $_userConditions');
      } else {
        print('No conditions found for user');
      }
    } catch (e) {
      print('Error fetching user conditions: $e');
    }
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
          // Get tags if they exist
          final tags = details['tags'] != null
              ? List<String>.from(details['tags'] as List<dynamic>)
              : <String>[];

          print('Processing video with key: $key');
          print('Video details: $details');

          if (videoUrl != null && videoUrl.isNotEmpty) {
            videos.add({
              'url': videoUrl,
              'title': details['title'] ?? 'Untitled Video',
              'details': details['details'] ?? 'No description available',
              'tags': tags,
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

  List<Map<String, dynamic>> _getFilteredVideos() {
    if (_userConditions.isEmpty) {
      return _videos;
    }

    return _videos.where((video) {
      List<String> videoTags = List<String>.from(video['tags'] ?? []);
      // Check if any of the video tags match any of the user conditions
      return videoTags.any((tag) => _userConditions.any((condition) =>
          condition.toLowerCase().trim() == tag.toLowerCase().trim()));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Always use filtered videos, remove the toggle functionality
    final filteredVideos = _videos.where((video) {
      if (_userConditions.isEmpty) return true;

      List<String> videoTags = List<String>.from(video['tags'] ?? []);
      return videoTags.any((tag) => _userConditions.any((condition) =>
          condition.toLowerCase().trim() == tag.toLowerCase().trim()));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Educational Videos'),
        actions: [
          // Only keep the refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUserConditionsAndVideos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredVideos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('No videos available for your condition'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchUserConditionsAndVideos,
                        child: const Text('Retry Loading Videos'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredVideos.length,
                  itemBuilder: (context, index) {
                    return VideoCard(
                      videoUrl: filteredVideos[index]['url'],
                      title: filteredVideos[index]['title'],
                      description: filteredVideos[index]['details'],
                      tags: filteredVideos[index]['tags'] ?? [],
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
  final List<String> tags;

  const VideoCard({
    Key? key,
    required this.videoUrl,
    required this.title,
    required this.description,
    this.tags = const [],
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
                // Display tags if available
                if (widget.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: widget.tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              backgroundColor: Colors.blue.shade100,
                              labelStyle: TextStyle(fontSize: 12),
                            ))
                        .toList(),
                  ),
                ],
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
