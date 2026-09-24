import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

start_idx = content.find('// ── SMART MEDIA URL FIELD')
if start_idx != -1:
    end_idx = content.find('// ── GALLERY IMAGES', start_idx)
    if end_idx != -1:
        new_ui = """// ── THUMBNAIL AND YOUTUBE MEDIA ──────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gig Thumbnail (Max 1MB)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _isUploadingImage ? null : _pickAndUploadImage,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: context.themeSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.5), width: 2, style: BorderStyle.solid),
                              image: _uploadedImageUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(_uploadedImageUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _isUploadingImage
                                ? const Center(child: CircularProgressIndicator.adaptive())
                                : _uploadedImageUrl.isEmpty
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.primary),
                                          const SizedBox(height: 12),
                                          Text('Tap to upload 16:9 thumbnail', style: GoogleFonts.inter(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                                        ],
                                      )
                                    : Align(
                                        alignment: Alignment.topRight,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: CircleAvatar(
                                            backgroundColor: Colors.black54,
                                            child: IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                                              onPressed: _pickAndUploadImage,
                                            ),
                                          ),
                                        ),
                                      ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'YouTube Video (Optional)',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.themeTextDark),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload your video to YouTube as "Unlisted" and paste the link here.',
                          style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _youtubeCtrl,
                          style: GoogleFonts.inter(color: context.themeTextDark, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'YouTube URL',
                            hintText: 'https://youtube.com/watch?v=...',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight),
                            labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.themeTextDark),
                            filled: true,
                            fillColor: context.themeSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                            ),
                            prefixIcon: const Icon(Icons.play_circle_outline_rounded, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    """
        content = content[:start_idx] + new_ui + content[end_idx:]
        with open('lib/screens/gig_editor_screen.dart', 'w') as f:
            f.write(content)
        print("Updated media UI successfully")
