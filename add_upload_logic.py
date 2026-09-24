import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

# Add imports for http and json if they are missing
if "import 'package:http/http.dart'" not in content:
    content = content.replace("import 'package:image_picker/image_picker.dart' as img_picker;", "import 'package:image_picker/image_picker.dart' as img_picker;\nimport 'package:http/http.dart' as http;\nimport 'dart:convert';")


upload_method = """
  Future<void> _pickAndUploadImage() async {
    final picker = img_picker.ImagePicker();
    final pickedFile = await picker.pickImage(
      source: img_picker.ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1920,
    );

    if (pickedFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://reskindev.com/upload.php'),
      );
      
      request.fields['freelancer_id'] = user.uid;
      request.files.add(await http.MultipartFile.fromPath('image', pickedFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['url'] != null) {
          setState(() {
            _uploadedImageUrl = data['url'];
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thumbnail uploaded successfully!')),
            );
          }
        } else {
          throw Exception(data['message'] ?? 'Upload failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _saveGig() async {"""

content = content.replace("  void _saveGig() async {", upload_method)

with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(content)
print("Added upload method")
