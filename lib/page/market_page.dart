import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/neumorphic.dart';
import '../utils/constants.dart';

class MarketPage extends StatelessWidget {
  const MarketPage({super.key});

  final List<Map<String, String>> _companies = const [
    {
      'name': 'BDO',
      'slogan': 'Your Banking Partner',
      'url': 'https://www.bdo.com.ph/',
    },
    {
      'name': 'BPI',
      'slogan': 'Banking with a Heart',
      'url': 'https://www.bpi.com.ph/',
    },
  ];

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: _companies.length,
          itemBuilder: (context, index) {
            final company = _companies[index];
            return NeumorphicCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    company['name']!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    company['slogan']!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _launchUrl(company['url']!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cta,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Learn More'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
