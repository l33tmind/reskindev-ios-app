import re

path = "./lib/screens/profile_screen.dart"
with open(path, "r") as f:
    content = f.read()

# 1. Change limit from 2 to 1
content = content.replace('recentChanges.length >= 2', 'recentChanges.length >= 1')
content = content.replace('2 username changes', '1 username change')

# 2. Re-insert the proper _onUsernameChanged without controller mutation crash
new_on_changed = """void _onUsernameChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final cleanValue = value.toLowerCase().trim();
    
    if (cleanValue.isEmpty || cleanValue == widget.auth.username) {
      setState(() {
        _usernameStatus = null;
        _usernameError = null;
      });
      return;
    }
    
    if (!_canChangeUsername) {
      setState(() {
        _usernameError = "You can only change your username 1 time within 30 days.";
        _usernameStatus = 'taken';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameStatus = null;
      _usernameError = null;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: cleanValue)
            .limit(1)
            .get();
            
        if (!mounted) return;
        
        bool isTaken = false;
        for (var d in query.docs) {
          if (d.id != widget.auth.user?.uid) {
            isTaken = true;
            break;
          }
        }
        
        setState(() {
          _isCheckingUsername = false;
          if (isTaken) {
            _usernameStatus = 'taken';
            _usernameError = "Taken ❌";
          } else {
            _usernameStatus = 'available';
            _usernameError = "Available ✅";
          }
        });
      } catch (e) {
        if (mounted) setState(() => _isCheckingUsername = false);
      }
    });
  }"""

content = re.sub(r'void _onUsernameChanged\(String value\) \{[\s\S]*?\}', new_on_changed, content, count=1)

# 3. Re-insert the proper _save
new_save = """Future<void> _save() async {
    if (_usernameStatus == 'taken' && _usernameCtrl.text != widget.auth.username) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose an available username.')));
      return;
    }

    setState(() => _saving = true);
    
    final newUsername = _usernameCtrl.text.toLowerCase().trim();
    if (newUsername != widget.auth.username && _canChangeUsername && newUsername.isNotEmpty) {
      final uid = widget.auth.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'usernameChanges': FieldValue.arrayUnion([FieldValue.serverTimestamp()])
        });
      }
    }

    await widget.auth.updateProfile(
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      username: newUsername.isEmpty ? null : newUsername,
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      company: _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
    );
    
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }"""

content = re.sub(r'Future<void> _save\(\) async \{[\s\S]*?Navigator\.pop\(context\);\s*\}', new_save, content, count=1)

# 4. We need to add inputFormatters support to _buildField function definition
content = re.sub(r'Widget _buildField\(\{\s*required TextEditingController controller,', 'Widget _buildField({\n    required TextEditingController controller,\n    List<TextInputFormatter>? inputFormatters,', content)
content = re.sub(r'readOnly: readOnly,\s*style:', 'readOnly: readOnly,\n      inputFormatters: inputFormatters,\n      style:', content)


# 5. Restore the UI for username field
ui_pattern = r'_buildField\(\s*controller: _usernameCtrl,\s*label: \'Username \(Auto-Generated\)\',\s*icon: Icons\.alternate_email,\s*readOnly: true,\s*\),'

new_ui = """_buildField(
                  controller: _usernameCtrl, 
                  label: 'Username', 
                  icon: Icons.alternate_email,
                  onChanged: _onUsernameChanged,
                  readOnly: !_canChangeUsername && _usernameCtrl.text != widget.auth.username,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                  ],
                  suffix: _isCheckingUsername 
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator.adaptive(strokeWidth: 2)),
                        )
                      : null,
                ),
                if (_usernameError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 16),
                    child: Text(
                      _usernameError!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _usernameStatus == 'taken' ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                if (!_canChangeUsername && _usernameError == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 16),
                    child: Text(
                      'You have reached the limit of 1 username change in 30 days.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.red),
                    ),
                  ),"""

content = re.sub(ui_pattern, new_ui, content, flags=re.DOTALL)

with open(path, "w") as f:
    f.write(content)
