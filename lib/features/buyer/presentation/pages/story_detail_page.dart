import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';

class StoryDetailPage extends StatelessWidget {
  final Map<String, String> story;

  const StoryDetailPage({
    super.key,
    required this.story,
  });

  @override
  Widget build(BuildContext context) {
    final title = story['title'] ?? 'Art & Heritage Story';
    final description = story['description'] ?? '';
    final imageUrl = story['image'] ?? '';

    return BuyerBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF8B261D)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Story Detail',
            style: GoogleFonts.montserrat(
              color: const Color(0xFF8B261D),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: imageUrl.startsWith('http')
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Image.asset(
                            'assets/main_page_elements/painting_main.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Image.asset(
                            'assets/main_page_elements/painting_main.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF6B1D1D),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                description,
                style: GoogleFonts.montserrat(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF331818),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
