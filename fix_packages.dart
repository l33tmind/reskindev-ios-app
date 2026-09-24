import 'dart:io';

void main() {
  final file = File('lib/screens/gig_editor_screen.dart');
  final lines = file.readAsLinesSync();
  
  final newContent = '''
                    // ── PACKAGE TIERS (TABS) ──────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitleInline('Packages & Features'),
                        if (_tiers.length < 3)
                          ElevatedButton.icon(
                            onPressed: _addTier,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Tier'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (_tiers.isNotEmpty) ...[
                      // Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_tiers.length, (index) {
                            final tier = _tiers[index];
                            final isSelected = _selectedTierIndex == index;
                            final color = _colorForTier(index);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(tier.nameCtrl.text.isEmpty ? 'Tier \${index+1}' : tier.nameCtrl.text),
                                selected: isSelected,
                                onSelected: (val) {
                                  if (val) setState(() => _selectedTierIndex = index);
                                },
                                selectedColor: color.withValues(alpha: 0.15),
                                labelStyle: GoogleFonts.inter(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? color : context.themeTextLight,
                                ),
                                side: BorderSide(color: isSelected ? color : context.themeBorder),
                                backgroundColor: context.themeSurface,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Active Tier Form
                      Builder(
                        builder: (context) {
                          if (_selectedTierIndex >= _tiers.length) _selectedTierIndex = _tiers.length - 1;
                          final idx = _selectedTierIndex;
                          final tier = _tiers[idx];
                          final color = _colorForTier(idx);
                          
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: context.themeSurface,
                              border: Border.all(color: color.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildTextField(tier.nameCtrl, 'Package Name', 'e.g. Basic')),
                                    if (_tiers.length > 1) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _tiers.removeAt(idx);
                                            _tierFeatureChecks.removeAt(idx);
                                            _selectedTierIndex = 0;
                                          });
                                        },
                                      ),
                                    ]
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: _buildTextField(tier.priceCtrl, 'Price (\$)', '0.0', isNumber: true)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildTextField(tier.deliveryCtrl, 'Delivery (Days)', '3', isNumber: true)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(tier.descCtrl, 'Package Description', 'What is included in this package?', maxLines: 2),
                                
                                const SizedBox(height: 24),
                                Text('Features Included', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                                const SizedBox(height: 12),
                                
                                if (_masterFeatures.isEmpty)
                                  Text('No features added yet.', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
                                  
                                ..._masterFeatures.asMap().entries.map((fEntry) {
                                  final fIdx = fEntry.key;
                                  final feature = fEntry.value;
                                  final isIncluded = _tierFeatureChecks[idx][feature] ?? false;
                                  
                                  return CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    dense: true,
                                    activeColor: color,
                                    title: Row(
                                      children: [
                                        Expanded(child: Text(feature, style: GoogleFonts.inter(fontSize: 13, color: context.themeTextDark))),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                                          onPressed: () {
                                            setState(() {
                                              _masterFeatures.removeAt(fIdx);
                                              for (var checkMap in _tierFeatureChecks) {
                                                checkMap.remove(feature);
                                              }
                                            });
                                          },
                                        )
                                      ],
                                    ),
                                    value: isIncluded,
                                    onChanged: (val) {
                                      setState(() {
                                        _tierFeatureChecks[idx][feature] = val ?? false;
                                      });
                                    },
                                  );
                                }),
                                
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _newFeatureCtrl,
                                        style: GoogleFonts.inter(fontSize: 13, color: context.themeTextDark),
                                        decoration: InputDecoration(
                                          hintText: 'Add new feature (e.g. Source Code)',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onSubmitted: (_) => _addMasterFeature(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _addMasterFeature,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Add'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                    ],
''';
  
  lines.replaceRange(680, 913, newContent.split('\n'));
  file.writeAsStringSync(lines.join('\n'));
}
