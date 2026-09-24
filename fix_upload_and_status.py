import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

# Add imports for image_picker and http
if "import 'package:image_picker/image_picker.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:image_picker/image_picker.dart';\nimport 'package:http/http.dart' as http;\nimport 'dart:convert';")

# Replace _status init and add the upload logic inside the _GigEditorScreenState class
start_init_state = content.find("  @override\n  void initState() {")

# Find the end of _save()
end_save = content.find("final Map<String, double> couponMap = {};")

if start_init_state != -1:
    # First let's fix the initStatus logic properly
    old_init = """    // Map legacy 'published' or unknown status to 'active' to match dropdown items
    String initStatus = g?.status ?? 'active';
    if (!['active', 'draft', 'pending'].contains(initStatus)) {
      initStatus = 'active';
    }
    _status = initStatus;"""

    new_init = """    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.uid == 'md-robius-sany' || user?.email?.toLowerCase() == 'mdrobiussany1225@gmail.com';
    
    String initStatus = g?.status ?? 'pending';
    if (isAdmin) {
      if (initStatus != 'active' && initStatus != 'pending' && initStatus != 'paused') {
        initStatus = 'active';
      }
    } else {
      initStatus = 'pending';
    }
    _status = initStatus;"""
    
    content = content.replace(old_init, new_init)

    # Now add the pick and upload function
    upload_functions = """  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    
    if (image == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      var uri = Uri.parse("https://reskindev.com/upload.php");
      var request = http.MultipartRequest("POST", uri);
      
      // Attach the image file
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      
      // Attach the freelancer ID
      request.fields['freelancer_id'] = user.uid;
      
      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            _uploadedImageUrl = jsonResponse['url'];
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded successfully!'), backgroundColor: Colors.green));
          }
        } else {
          throw Exception(jsonResponse['message'] ?? 'Upload failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading image: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  @override
  void initState() {"""
    
    content = content.replace("  @override\n  void initState() {", upload_functions)

    # Add the UI for image upload
    old_youtube_ui = """                    _buildSectionTitle('Media'),
                    _buildTextField(_youtubeCtrl, 'YouTube Video URL or Image URL (Optional)', 'e.g. https://youtu.be/...'),"""
                    
    new_youtube_ui = """                    _buildSectionTitle('Media'),
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
                              border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
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
                    ),"""
    
    content = content.replace(old_youtube_ui, new_youtube_ui)
    
    with open('lib/screens/gig_editor_screen.dart', 'w') as f:
        f.write(content)
    print("Injected image upload and fixed status")
else:
    print("Could not find start_init_state")
