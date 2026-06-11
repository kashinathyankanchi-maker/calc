import 'dart:convert';
import 'package:http/http.dart' as http;

class GitHubProfile {
  final String username;
  final String name;
  final String avatarUrl;
  final int publicRepos;
  final int followers;
  final int following;
  final int publicGists;
  final String bio;

  GitHubProfile({
    required this.username,
    required this.name,
    required this.avatarUrl,
    required this.publicRepos,
    required this.followers,
    required this.following,
    required this.publicGists,
    required this.bio,
  });

  factory GitHubProfile.fromJson(Map<String, dynamic> json) {
    return GitHubProfile(
      username: json['login'] ?? '',
      name: json['name'] ?? json['login'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      publicRepos: json['public_repos'] ?? 0,
      followers: json['followers'] ?? 0,
      following: json['following'] ?? 0,
      publicGists: json['public_gists'] ?? 0,
      bio: json['bio'] ?? 'No bio available',
    );
  }
}

class GitHubService {
  static Future<GitHubProfile?> fetchUserProfile(String username) async {
    if (username.trim().isEmpty) return null;
    
    final url = Uri.parse('https://api.github.com/users/$username');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return GitHubProfile.fromJson(data);
      }
    } catch (e) {
      // Return null on network error or parsing error
      print('GitHub API Error: $e');
    }
    return null;
  }
}
