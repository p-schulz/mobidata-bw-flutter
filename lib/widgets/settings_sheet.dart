import 'package:flutter/material.dart';

import '../models/app_theme_setting.dart';

class SettingsSheet extends StatefulWidget {
  final bool autoLoadOnMove;
  final bool openDrawerOnStart;
  final ValueChanged<bool> onChangeAutoLoadOnMove;
  final ValueChanged<bool> onChangeOpenDrawerOnStart;

  final AppThemeSetting appThemeSetting;
  final ValueChanged<AppThemeSetting> onChangeTheme; // NEU

  const SettingsSheet({
    required this.autoLoadOnMove,
    required this.openDrawerOnStart,
    required this.onChangeAutoLoadOnMove,
    required this.onChangeOpenDrawerOnStart,
    required this.appThemeSetting,
    required this.onChangeTheme,
  });

  @override
  State<SettingsSheet> createState() => SettingsSheetState();
}

class SettingsSheetState extends State<SettingsSheet> {
  late bool _autoLoadOnMove;
  late bool _openDrawerOnStart;
  late AppThemeSetting _appThemeSetting;

  @override
  void initState() {
    super.initState();
    _autoLoadOnMove = widget.autoLoadOnMove;
    _openDrawerOnStart = widget.openDrawerOnStart;
    _appThemeSetting = widget.appThemeSetting;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text('Einstellungen', style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 12),

              //const SizedBox(height: 16),
              Text('Darstellung', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),

              RadioListTile<AppThemeSetting>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Systemeinstellung verwenden'),
                value: AppThemeSetting.system,
                groupValue: _appThemeSetting,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _appThemeSetting = val);
                  widget.onChangeTheme(val);
                },
              ),
              RadioListTile<AppThemeSetting>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Helles Design'),
                value: AppThemeSetting.light,
                groupValue: _appThemeSetting,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _appThemeSetting = val);
                  widget.onChangeTheme(val);
                },
              ),
              RadioListTile<AppThemeSetting>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dunkles Design'),
                value: AppThemeSetting.dark,
                groupValue: _appThemeSetting,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _appThemeSetting = val);
                  widget.onChangeTheme(val);
                },
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Parkplätze beim Kartenverschieben automatisch nachladen',
                ),
                subtitle: const Text(
                  'Deaktivieren, wenn nur manuell über den Refresh-Button geladen werden soll.',
                ),
                value: _autoLoadOnMove,
                onChanged: (val) {
                  setState(() => _autoLoadOnMove = val);
                  widget.onChangeAutoLoadOnMove(
                    val,
                  ); // an HomeScreen weitergeben
                },
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Drawer beim App-Start automatisch öffnen'),
                value: _openDrawerOnStart,
                onChanged: (val) {
                  setState(() => _openDrawerOnStart = val);
                  widget.onChangeOpenDrawerOnStart(val);
                },
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
