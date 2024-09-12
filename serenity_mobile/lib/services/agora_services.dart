class AgoraService {
  // Hardcoded channel name and token for testing
  final String _channelName =
      'njalbeos'; // Replace with your desired channel name
  final String _token =
      '007eJxTYGB10zhjai7y4/bGzl2iO478cpkf8Xzz29TUtX7H3zTXbc9RYDBONE9KMzYxTk02NTAxMjOzNDc0MTGzME81NUpJS0w2Uw98nNYQyMhg5aHFxMgAgSA+B0NeVmJOUmp+MQMDACQXIYc='; // Replace with your temporary token from the Agora Console

  Future<String?> fetchToken(String channelName) async {
    // If you want to validate the channel name passed, do so here
    if (channelName.isNotEmpty) {
      // Return the hardcoded token
      return _token;
    } else {
      print('Channel name is empty');
      return null;
    }
  }

  // Method to return the hardcoded channel name
  String getChannelName() {
    return _channelName;
  }
}
