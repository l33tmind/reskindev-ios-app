import re

with open('lib/screens/profile_screen.dart', 'r') as f:
    content = f.read()

# Replace _showEditProfileModal definition
old_modal = """  void _showEditProfileModal(BuildContext context, ap.AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Information', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: context.themeTextDark)),
              const SizedBox(height: 8),
              Text('These details are auto-filled in orders.', style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
              const SizedBox(height: 24),
              _buildField(controller: _nameCtrl, label: 'Full Name', icon: Icons.person_outline),
              const SizedBox(height: 16),
              _buildField(controller: _phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildField(controller: _companyCtrl, label: 'Company Name', icon: Icons.business_outlined),
              const SizedBox(height: 16),
              _buildField(controller: _addressCtrl, label: 'Address', icon: Icons.location_on_outlined, maxLines: 2),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    _save();
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Save Changes', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }"""

new_modal = """  void _showEditProfileModal(BuildContext context, ap.AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(auth: auth, parentContext: context),
    );
  }"""

if old_modal in content:
    content = content.replace(old_modal, new_modal)
    with open('lib/screens/profile_screen.dart', 'w') as f:
        f.write(content)
    print("Replaced modal call")
else:
    print("Could not find old_modal block")
