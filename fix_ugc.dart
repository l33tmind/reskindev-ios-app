import 'dart:io';

void main() {
  final file = File('lib/screens/gig_editor_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Add state variable
  content = content.replaceFirst(
    "String _status = 'active';",
    "String _status = 'active';\n  bool _ugcAccepted = false;"
  );
  
  // 2. Add validation in _save()
  final saveValidation = '''
    if (!_formKey.currentState!.validate()) return;
    
    if (_mediaCtrl.text.trim().isNotEmpty && !_ugcAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must accept the Mandatory UGC & Copyright Declaration.'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _isSaving = true);
''';
  content = content.replaceFirst(
    '''
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);''',
    saveValidation
  );
  
  // 3. Add Checkbox UI
  final checkboxUI = '''
                            ],
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _ugcAccepted,
                                      onChanged: (val) {
                                        setState(() => _ugcAccepted = val ?? false);
                                        setLocal(() {});
                                      },
                                      activeColor: AppTheme.primary,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(text: 'Mandatory UGC & Copyright Declaration: ', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: context.themeTextDark)),
                                          TextSpan(text: 'I confirm this media is uploaded by me. I acknowledge that I am submitting User-Generated Content (UGC) and warrant that I own all intellectual property rights. I agree not to submit any copyrighted, objectionable, or abusive material. I grant permission to embed this media and assume full legal liability for its content.', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight, height: 1.4)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
''';
  content = content.replaceFirst(
    '''
                            ],
                          ],
                        );''',
    checkboxUI
  );

  file.writeAsStringSync(content);
}
