import re

with open('lib/screens/settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add _batteryIgnored field
content = content.replace(
    '  bool _exactAlarmsAllowed = false;',
    '  bool _exactAlarmsAllowed = false;\n  bool _batteryIgnored = false;'
)

# 2. Update _checkPermissions to check battery
old_check = '''    final notifs = await NotificationService.instance.checkNotificationPermission();
    final exact = await NotificationService.instance.checkExactAlarmPermission();

    if (mounted) {
      setState(() {
        _notificationsAllowed = notifs;
        _exactAlarmsAllowed = exact;
        _isLoadingPermissions = false;'''

new_check = '''    final notifs = await NotificationService.instance.checkNotificationPermission();
    final exact = await NotificationService.instance.checkExactAlarmPermission();
    final battery = await NotificationService.instance.isBatteryOptimizationIgnored();

    if (mounted) {
      setState(() {
        _notificationsAllowed = notifs;
        _exactAlarmsAllowed = exact;
        _batteryIgnored = battery;
        _isLoadingPermissions = false;'''

content = content.replace(old_check, new_check)

# 3. Remove emojis in snackbars & strings
content = content.replace("'✅ Notification permission granted!'", "'Notification permission granted!'")
content = content.replace("'❌ Notification permission was not granted.'", "'Notification permission was not granted.'")
content = content.replace('Tap "🛑 Stop Alarm" to dismiss.', 'Tap "Stop Alarm" to dismiss.')
content = content.replace("'🔔 Ringing test alarm with ${currentRingtone.name}! Check your status bar.'", "'Ringing test alarm with ${currentRingtone.name}! Check status bar.'")
content = content.replace("'🛑 Alarm test cancelled and active test alarms stopped.'", "'Alarm test cancelled and active test alarms stopped.'")
content = content.replace("'✅ Alert timing saved: rings every $tempInterval min up to deadline.'", "'Alert timing saved: rings every $tempInterval min up to deadline.'")
content = content.replace("'🔔 Ring Test Alarm Right Now'", "'Ring Test Alarm Right Now'")
content = content.replace("'🛑 Stop Test Alarm & Reset'", "'Stop Test Alarm & Reset'")

# 4. In _openPermissionsModal, add 3rd permission item for 1-Tap battery
old_perm_modal = '''            const SizedBox(height: 12),
            _buildPermissionItem(
              title: 'Exact Alarms (Schedule)',
              desc: 'Required on Android 12, 13 & 14 to wake the device at the exact target second.',
              isGranted: _exactAlarmsAllowed,
              onRequest: () async {
                await _requestExactAlarmPermission();
                mSetState(() {});
              },
            ),
            const SizedBox(height: 20),'''

new_perm_modal = '''            const SizedBox(height: 12),
            _buildPermissionItem(
              title: 'Exact Alarms (Schedule)',
              desc: 'Required on Android 12, 13 & 14 to wake the device at the exact target second.',
              isGranted: _exactAlarmsAllowed,
              onRequest: () async {
                await _requestExactAlarmPermission();
                mSetState(() {});
              },
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              title: '1-Tap Background (Battery Optimization)',
              desc: 'Allows alarms to ring when app is closed. Tapping grants Unrestricted battery mode.',
              isGranted: _batteryIgnored,
              onRequest: () async {
                await NotificationService.instance.requestIgnoreBatteryOptimization();
                await Future.delayed(const Duration(milliseconds: 500));
                await _checkPermissions();
                mSetState(() {});
              },
            ),
            const SizedBox(height: 12),
            // Auto-start quick link
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_power_rounded, size: 16, color: emeraldGreen),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ZTE, Xiaomi & Samsung phones:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                  ),
                  InkWell(
                    onTap: () => NotificationService.instance.openAutoStartSettings(),
                    child: const Text(
                      'Auto-Start Settings',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: emeraldGreen),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),'''

content = content.replace(old_perm_modal, new_perm_modal)

# 5. Replace _openRingtoneModal with category filtering and all 21 ringtones
old_ringtone_modal = '''  // --- 2. MODAL: ALARM RINGTONE SELECTOR ---
  void _openRingtoneModal() {
    _showModalPopup(
      context: context,
      title: 'Alarm Ringtone & Sound',
      icon: Icons.notifications_active_rounded,
      builder: (mCtx, mSetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select an authentic alarm sound. The selected ringtone will loop continuously through the Android Alarm Stream (STREAM_ALARM) until dismissed.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
            ),
            const SizedBox(height: 16),
            ...NotificationService.availableRingtones.map((ringtone) {
              final isSelected = ringtone.id == _selectedRingtoneId;
              final isPlaying = _previewingRingtoneId == ringtone.rawResourceName;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected ? emeraldGreen.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? emeraldGreen : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      await _selectRingtone(ringtone);
                      mSetState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? emeraldGreen.withValues(alpha: 0.15)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          ringtone.icon,
                          color: isSelected ? emeraldGreen : const Color(0xFF475569),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    ringtone.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? emeraldGreen : const Color(0xFF171717),
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: emeraldGreen,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ringtone.subtitle,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Preview Button
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: isPlaying
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFF1F5F9),
                          foregroundColor: isPlaying ? const Color(0xFFEF4444) : const Color(0xFF475569),
                        ),
                        icon: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 20),
                        tooltip: isPlaying ? 'Stop preview' : 'Play preview',
                        onPressed: () async {
                          await _togglePreview(ringtone);
                          mSetState(() {});
                        },
                      ),
                      const SizedBox(width: 4),
                      // Select Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? emeraldGreen : const Color(0xFF171717),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          await _selectRingtone(ringtone);
                          mSetState(() {});
                        },
                        child: Text(
                          isSelected ? 'Selected' : 'Use',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
          ],
        );
      },
    );
  }'''

new_ringtone_modal = '''  // --- 2. MODAL: ALARM RINGTONE SELECTOR ---
  void _openRingtoneModal() {
    String selectedCategory = 'All';
    final categories = [
      'All',
      'Simple Notification',
      'Alert Sound',
      'Long Sound',
      'Melody',
      'Low Volume',
      'Alarm',
    ];

    _showModalPopup(
      context: context,
      title: 'Alarm Ringtone & Sound',
      icon: Icons.notifications_active_rounded,
      builder: (mCtx, mSetState) {
        final filteredRingtones = selectedCategory == 'All'
            ? NotificationService.availableRingtones
            : NotificationService.availableRingtones
                .where((r) => r.category == selectedCategory)
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select from 21 distinct ringtones across 6 sound styles. The active sound loops continuously through the Android Alarm Stream (STREAM_ALARM) until dismissed.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
            ),
            const SizedBox(height: 12),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isCatSel = selectedCategory == cat;
                  final count = cat == 'All'
                      ? NotificationService.availableRingtones.length
                      : NotificationService.availableRingtones
                          .where((r) => r.category == cat)
                          .length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$cat ($count)'),
                      selected: isCatSel,
                      selectedColor: emeraldGreen,
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isCatSel ? Colors.white : const Color(0xFF334155),
                      ),
                      showCheckmark: false,
                      onSelected: (val) {
                        if (val) {
                          mSetState(() {
                            selectedCategory = cat;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            ...filteredRingtones.map((ringtone) {
              final isSelected = ringtone.id == _selectedRingtoneId;
              final isPlaying = _previewingRingtoneId == ringtone.rawResourceName;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected ? emeraldGreen.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? emeraldGreen : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      await _selectRingtone(ringtone);
                      mSetState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? emeraldGreen.withValues(alpha: 0.15)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          ringtone.icon,
                          color: isSelected ? emeraldGreen : const Color(0xFF475569),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    ringtone.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? emeraldGreen : const Color(0xFF171717),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    ringtone.category,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: emeraldGreen,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ringtone.subtitle,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Preview Button
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: isPlaying
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFF1F5F9),
                          foregroundColor: isPlaying ? const Color(0xFFEF4444) : const Color(0xFF475569),
                        ),
                        icon: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 20),
                        tooltip: isPlaying ? 'Stop preview' : 'Play preview',
                        onPressed: () async {
                          await _togglePreview(ringtone);
                          mSetState(() {});
                        },
                      ),
                      const SizedBox(width: 4),
                      // Select Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? emeraldGreen : const Color(0xFF171717),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          await _selectRingtone(ringtone);
                          mSetState(() {});
                        },
                        child: Text(
                          isSelected ? 'Selected' : 'Use',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
          ],
        );
      },
    );
  }'''

content = content.replace(old_ringtone_modal, new_ringtone_modal)

# 6. Replace _openBatteryGuideModal with 1-Tap button & ZTE guide
old_battery_modal = '''  // --- 5. MODAL: BATTERY OPTIMIZATION GUIDE ---
  void _openBatteryGuideModal() {
    _showModalPopup(
      context: context,
      title: 'Battery Optimization Guide',
      icon: Icons.battery_saver_rounded,
      builder: (mCtx, mSetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Some Android manufacturers aggressively close background apps in deep sleep. To guarantee your alarms ring on time, adjust battery settings for Task Scheduler:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.35),
            ),
            const SizedBox(height: 16),
            _buildBrandGuide(
              brand: 'Samsung (OneUI)',
              steps: 'Settings > Apps > Task Scheduler > Battery > Select "Unrestricted".',
            ),
            _buildBrandGuide(
              brand: 'Xiaomi / Redmi / POCO (MIUI / HyperOS)',
              steps: 'Long-press app icon > App Info > Battery Saver > Select "No restrictions" and enable "Autostart".',
            ),
            _buildBrandGuide(
              brand: 'Oppo / Realme / OnePlus (ColorOS / OxygenOS)',
              steps: 'Settings > Battery > More battery settings > App battery management > Allow background activity.',
            ),
            _buildBrandGuide(
              brand: 'Vivo / iQOO (Funtouch OS)',
              steps: 'Settings > Battery > Background power consumption management > Set Task Scheduler to "Allow high background power consumption".',
            ),
            _buildBrandGuide(
              brand: 'Google Pixel / Motorola / Stock Android',
              steps: 'Settings > Apps > Task Scheduler > App battery usage > Select "Unrestricted".',
            ),
          ],
        );
      },
    );
  }'''

new_battery_modal = '''  // --- 5. MODAL: BATTERY OPTIMIZATION GUIDE ---
  void _openBatteryGuideModal() {
    _showModalPopup(
      context: context,
      title: 'Background & Battery Optimization',
      icon: Icons.battery_charging_full_rounded,
      builder: (mCtx, mSetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _batteryIgnored
                    ? emeraldGreen.withValues(alpha: 0.1)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _batteryIgnored
                      ? emeraldGreen.withValues(alpha: 0.3)
                      : const Color(0xFFFCA5A5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _batteryIgnored ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    color: _batteryIgnored ? emeraldGreen : const Color(0xFFEF4444),
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _batteryIgnored
                              ? 'Battery Mode: Unrestricted (Active)'
                              : 'Battery Mode: Optimized / Restricted',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: _batteryIgnored ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _batteryIgnored
                              ? 'Alarms are allowed to wake device and ring continuously even when app is closed.'
                              : 'ZTE SuperKiller and OEM cleaners can terminate alarms when swiped from recents.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _batteryIgnored ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 1-Tap Allow Button
            if (!_batteryIgnored) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: emeraldGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 20),
                label: const Text(
                  '1-Tap Allow Background (Unrestricted)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await NotificationService.instance.requestIgnoreBatteryOptimization();
                  await Future.delayed(const Duration(milliseconds: 500));
                  await _checkPermissions();
                  mSetState(() {});
                },
              ),
              const SizedBox(height: 10),
            ],

            // Auto-Start Launcher Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF171717),
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.settings_power_rounded, size: 18, color: emeraldGreen),
              label: const Text(
                'Open Phone Auto-Start Settings',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: () => NotificationService.instance.openAutoStartSettings(),
            ),
            const SizedBox(height: 18),

            const Text(
              'Manufacturer Setup Instructions:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
            ),
            const SizedBox(height: 10),

            _buildBrandGuide(
              brand: 'ZTE (SuperKiller & PowerSave)',
              steps: 'Open Settings > Apps > Task Scheduler > Battery > Select "Unrestricted" and enable "Auto-start" and "Display pop-up windows". In Recent Apps, tap lock on Task Scheduler card.',
            ),
            _buildBrandGuide(
              brand: 'Samsung (OneUI)',
              steps: 'Settings > Apps > Task Scheduler > Battery > Select "Unrestricted".',
            ),
            _buildBrandGuide(
              brand: 'Xiaomi / Redmi / POCO (MIUI / HyperOS)',
              steps: 'Long-press app icon > App Info > Battery Saver > Select "No restrictions" and enable "Autostart".',
            ),
            _buildBrandGuide(
              brand: 'Oppo / Realme / OnePlus (ColorOS / OxygenOS)',
              steps: 'Settings > Battery > More battery settings > App battery management > Allow background activity.',
            ),
            _buildBrandGuide(
              brand: 'Vivo / iQOO (Funtouch OS)',
              steps: 'Settings > Battery > Background power consumption management > Set Task Scheduler to "Allow high background power consumption".',
            ),
            _buildBrandGuide(
              brand: 'Google Pixel / Motorola / Stock Android',
              steps: 'Settings > Apps > Task Scheduler > App battery usage > Select "Unrestricted".',
            ),
          ],
        );
      },
    );
  }'''

content = content.replace(old_battery_modal, new_battery_modal)

# 7. Update main list items:
old_tile_perm = '''                  _buildSettingTile(
                    icon: Icons.security_rounded,
                    title: 'System Permissions',
                    subtitle: permissionsOk ? 'All active (2/2 permissions)' : 'Action required (Pending permissions)',
                    badgeText: permissionsOk ? 'ACTIVE' : 'ACTION REQUIRED',
                    badgeColor: permissionsOk ? emeraldGreen : const Color(0xFFEF4444),
                    onTap: _openPermissionsModal,
                  ),'''

new_tile_perm = '''                  _buildSettingTile(
                    icon: Icons.security_rounded,
                    title: 'System Permissions',
                    subtitle: (permissionsOk && _batteryIgnored) ? 'All active (Notifications, Exact Alarm, Background)' : 'Action required (Pending permissions)',
                    badgeText: (permissionsOk && _batteryIgnored) ? 'ACTIVE' : 'ACTION REQUIRED',
                    badgeColor: (permissionsOk && _batteryIgnored) ? emeraldGreen : const Color(0xFFEF4444),
                    onTap: _openPermissionsModal,
                  ),'''

content = content.replace(old_tile_perm, new_tile_perm)

old_tile_battery = '''                  // 5. Battery Guide Card
                  _buildSettingTile(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Android Battery Optimization Guide',
                    subtitle: 'Ensure alarms wake Xiaomi, Samsung & Oppo phones',
                    badgeText: 'GUIDE',
                    badgeColor: const Color(0xFF64748B),
                    onTap: _openBatteryGuideModal,
                  ),'''

new_tile_battery = '''                  // 5. Battery & Background Card
                  _buildSettingTile(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Background & Battery Optimization',
                    subtitle: _batteryIgnored
                        ? 'Unrestricted background active for ZTE & Android'
                        : '1-tap allow so alarms wake phone when closed',
                    badgeText: _batteryIgnored ? 'UNRESTRICTED' : '1-TAP ALLOW',
                    badgeColor: _batteryIgnored ? emeraldGreen : const Color(0xFFF59E0B),
                    onTap: _openBatteryGuideModal,
                  ),'''

content = content.replace(old_tile_battery, new_tile_battery)

with open('lib/screens/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('SETTINGS SCREEN UPDATED SUCCESSFULLY!')
