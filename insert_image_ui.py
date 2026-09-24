import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

# Locate the place to insert the Image Upload UI.
# It should be before the Tiers or Gallery sections. Let's find "if (_tiers.isNotEmpty) ...["
target = "if (_tiers.isNotEmpty) ...["

if target in content:
    image_ui = """_buildSectionTitle('Media'),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thumbnail Image', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _isUploadingImage ? null : _pickAndUploadImage,
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: context.themeSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black.withOpacity(0.15)),
                              image: _uploadedImageUrl.isNotEmpty 
                                ? DecorationImage(image: NetworkImage(_uploadedImageUrl), fit: BoxFit.cover)
                                : null,
                            ),
                            child: _isUploadingImage
                                ? const Center(child: CircularProgressIndicator.adaptive())
                                : _uploadedImageUrl.isEmpty
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.cloud_upload_outlined, size: 40, color: context.themeTextLight),
                                          const SizedBox(height: 8),
                                          Text('Tap to upload image', style: GoogleFonts.inter(color: context.themeTextLight)),
                                        ],
                                      )
                                    : Align(
                                        alignment: Alignment.topRight,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                                          onPressed: () => setState(() => _uploadedImageUrl = ''),
                                        ),
                                      ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(_youtubeCtrl, 'YouTube Video URL (Optional)', 'e.g. https://youtu.be/...'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    """
    content = content.replace(target, image_ui + target)
    with open('lib/screens/gig_editor_screen.dart', 'w') as f:
        f.write(content)
    print("Inserted image upload UI")
else:
    print("Could not find target")

