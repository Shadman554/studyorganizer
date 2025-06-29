// lib/pages/about_me_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutMePage extends StatelessWidget {
  const AboutMePage({super.key});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('About Me'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            
            // Profile Image
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.teal : Colors.teal[700]!,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    spreadRadius: 5,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/icons/shadman.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading image: $error');
                    return Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        size: 80,
                        color: isDark ? Colors.tealAccent : Colors.teal,
                      ),
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Name
            Text(
              'Shadman Othman',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.onBackground,
                shadows: [
                  Shadow(
                    color: Colors.teal.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Title/Role
            Text(
              'Mobile App Developer & Veterinary Student',
              style: TextStyle(
                fontSize: 18,
                color: isDark ? Colors.tealAccent : Colors.teal[700],
                fontStyle: FontStyle.italic,
              ),
            ),
            
            const SizedBox(height: 30),
            
            // About Me Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: (isDark ? Colors.teal : Colors.teal[700])!.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Me',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.tealAccent : Colors.teal[700],
                    ),
                  ),
                  Container(
                    height: 2,
                    width: 100,
                    color: isDark ? Colors.tealAccent : Colors.teal[700],
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
                  ),
                  Text(
                    'I am a passionate mobile app developer and veterinary student with a love for coding. I built WANAKANM to help students like me organize lectures, track study time, and stay on top of their study calendar.\n\nThe app includes flashcards and AI tools that automatically generate questions, summarize lectures, and highlight key points to help students study smarter and enhance their learning experience. My goal is to combine my technical skills with my background in veterinary medicine to create tools that make education more efficient and accessible.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Social Media Links
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: (isDark ? Colors.teal : Colors.teal[700])!.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect With Me',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.tealAccent : Colors.teal[700],
                    ),
                  ),
                  Container(
                    height: 2,
                    width: 150,
                    color: isDark ? Colors.tealAccent : Colors.teal[700],
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
                  ),
                  
                  // Facebook
                  InkWell(
                    onTap: () => _launchURL('https://www.facebook.com/shadman.osman.2025'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1877F2).withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1877F2).withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.facebook,
                            color: const Color(0xFF1877F2),
                            size: 28,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Facebook',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: colorScheme.onSurface.withOpacity(0.5),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Instagram
                  InkWell(
                    onTap: () => _launchURL('https://www.instagram.com/shadman_osman1?igsh=MWF0N3QwcWcwZ2dpdw=='),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1306C).withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE1306C).withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.camera_alt,
                            color: const Color(0xFFE1306C),
                            size: 28,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Instagram',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: colorScheme.onSurface.withOpacity(0.5),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // App Version
            Text(
              'WANAKANM v1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[600] : Colors.grey[500],
              ),
            ),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
