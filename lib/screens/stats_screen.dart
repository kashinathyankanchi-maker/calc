import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../github_service.dart';

class StatsScreen extends StatefulWidget {
  final Function(String) onInsertValue;
  final VoidCallback onSwitchToCalculator;

  const StatsScreen({
    super.key,
    required this.onInsertValue,
    required this.onSwitchToCalculator,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  GitHubProfile? _profile;
  String _errorMessage = '';

  // Theme Constants
  static const Color bgColor = Color(0xFF0D1117);
  static const Color cardColor = Color(0xFF161B22);
  static const Color borderCol = Color(0xFF30363D);
  static const Color textMain = Color(0xFFC9D1D9);
  static const Color textMuted = Color(0xFF8B949E);
  static const Color gitBlue = Color(0xFF58A6FF);
  static const Color gitGreen = Color(0xFF238636);
  static const Color gitRed = Color(0xFFDA3633);
  static const Color btnDark = Color(0xFF21262D);

  void _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _profile = null;
    });

    final profile = await GitHubService.fetchUserProfile(query);

    setState(() {
      _isLoading = false;
      if (profile != null) {
        _profile = profile;
      } else {
        _errorMessage = 'User not found or connection failed';
      }
    });
  }

  // Generates a mock list of contribution densities (0 to 4) for the grid
  List<int> _generateMockContributions() {
    final Random random = Random();
    return List.generate(105, (index) => random.nextInt(5));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(color: textMain),
                  cursorColor: gitBlue,
                  decoration: InputDecoration(
                    hintText: 'Enter GitHub username...',
                    hintStyle: GoogleFonts.inter(color: textMuted),
                    fillColor: cardColor,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(color: borderCol, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(color: gitBlue, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _searchUser(),
                ),
              ),
              const SizedBox(width: 12.0),
              ElevatedButton(
                onPressed: _searchUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gitBlue,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Icon(Icons.search, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 20.0),

          // Display Results
          Expanded(
            child: SingleChildScrollView(
              child: _buildResultsArea(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsArea() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 60.0),
          child: CircularProgressIndicator(color: gitBlue),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 60.0),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: gitRed, size: 48.0),
              const SizedBox(height: 12.0),
              Text(
                _errorMessage,
                style: GoogleFonts.inter(color: gitRed, fontSize: 16.0),
              ),
            ],
          ),
        ),
      );
    }

    if (_profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 80.0),
          child: Column(
            children: [
              const Icon(Icons.device_hub, color: textMuted, size: 60.0),
              const SizedBox(height: 16.0),
              Text(
                'Search GitHub profiles to use their stats in your calculations!',
                textAlign: Center,
                style: GoogleFonts.inter(color: textMuted, fontSize: 15.0),
              ),
            ],
          ),
        ),
      );
    }

    final mockContributions = _generateMockContributions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Summary Card
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: borderCol, width: 1.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 36.0,
                backgroundColor: borderCol,
                backgroundImage: NetworkImage(_profile!.avatarUrl),
              ),
              const SizedBox(width: 16.0),
              
              // Identity & Bio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile!.name,
                      style: GoogleFonts.inter(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                      ),
                    ),
                    Text(
                      '@${_profile!.username}',
                      style: GoogleFonts.firaCode(
                        fontSize: 14.0,
                        color: gitBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      _profile!.bio,
                      style: GoogleFonts.inter(
                        fontSize: 13.0,
                        color: textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20.0),

        // Helper instruction text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              const Icon(Icons.touch_app, color: gitBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                'Tap a stat to insert it into your calculator:',
                style: GoogleFonts.inter(
                  color: textMuted,
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10.0),

        // Stats Grid Buttons
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          children: [
            _buildStatButton('Public Repos', _profile!.publicRepos.toString()),
            _buildStatButton('Followers', _profile!.followers.toString()),
            _buildStatButton('Following', _profile!.following.toString()),
            _buildStatButton('Public Gists', _profile!.publicGists.toString()),
          ],
        ),
        const SizedBox(height: 24.0),

        // Contribution Grid Title
        Text(
          'Contribution Graph',
          style: GoogleFonts.inter(
            color: textMain,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10.0),

        // Contribution Grid
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: borderCol, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: mockContributions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 15,
                  crossAxisSpacing: 3.0,
                  mainAxisSpacing: 3.0,
                ),
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: _getContributionColor(mockContributions[index]),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Less  ', style: GoogleFonts.inter(color: textMuted, fontSize: 11.0)),
                  _buildLegendBox(0),
                  _buildLegendBox(1),
                  _buildLegendBox(2),
                  _buildLegendBox(3),
                  _buildLegendBox(4),
                  Text('  More', style: GoogleFonts.inter(color: textMuted, fontSize: 11.0)),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatButton(String label, String value) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onInsertValue(value);
          widget.onSwitchToCalculator();
        },
        borderRadius: BorderRadius.circular(10.0),
        child: Ink(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: borderCol, width: 1.0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: textMuted,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                value,
                style: GoogleFonts.firaCode(
                  color: gitBlue,
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getContributionColor(int level) {
    switch (level) {
      case 0:
        return const Color(0xFF161B22); // Empty/Background
      case 1:
        return const Color(0xFF0E4429); // Light green
      case 2:
        return const Color(0xFF006D32); // Medium green
      case 3:
        return const Color(0xFF26A641); // Bright green
      case 4:
        return const Color(0xFF39D353); // Bold green
      default:
        return const Color(0xFF161B22);
    }
  }

  Widget _buildLegendBox(int level) {
    return Container(
      width: 10.0,
      height: 10.0,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: _getContributionColor(level),
        borderRadius: BorderRadius.circular(1.0),
      ),
    );
  }
}
