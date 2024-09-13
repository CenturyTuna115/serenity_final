class AgoraService {
  // Hardcoded channel name and token for testing
  final String _channelName =
      'njalbeos'; // Replace with your desired channel name
  final String _token =
      '007eJxTYHC81mZbJz6X3//RbZOpIbEF/QEzwg1EpkostskP+P689aECg3GieVKasYlxarKpgYmRmZmluaGJiZmFeaqpUUpaYrIZ/7fHaQ2BjAynE61ZGBkgEMTnYMjLSsxJSs0vZmAAAGogIBQ=';

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
